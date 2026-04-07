"""
GymLog - Gravitus CSV Import Script
=====================================
Importuje historię treningów z Gravitusa do GymLog (Supabase).

Użycie:
  python import_gravitus.py <plik.csv> <email> <hasło>

Przykład:
  python import_gravitus.py export_20260404_081922.csv jakub1urbabuak@gmail.com TwojeHaslo123
"""

import sys, re, csv, io
from collections import defaultdict
from datetime import datetime, timedelta

try:
    from supabase import create_client
except ImportError:
    import subprocess; subprocess.run([sys.executable, "-m", "pip", "install", "supabase", "--break-system-packages", "-q"])
    from supabase import create_client

SUPABASE_URL = "https://vderfviqeeacpboannlo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkZXJmdmlxZWVhY3Bib2FubmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyNDU4NzAsImV4cCI6MjA5MDgyMTg3MH0.Dhn_leiQGA1ukzz4h9EqyhjyhvlWMR96FsBRxHM7yic"

def parse_csv(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        raw = f.read()

    workouts = {}
    sets = []
    section = None

    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue

        if stripped == 'Workouts,,,,,,,,,,,':
            section = 'workouts_header'; continue
        if stripped == 'Workout Sets,,,,,,,,,,,':
            section = 'sets_header'; continue
        if section == 'workouts_header' and stripped.startswith('created,'):
            section = 'workouts'; continue
        if section == 'sets_header' and stripped.startswith('group_number,'):
            section = 'sets'; continue
        if section in ('workouts', 'sets') and stripped and not (stripped[0].isdigit() or stripped[0] == '"'):
            section = None; continue

        if section == 'workouts':
            try:
                row = next(csv.reader(io.StringIO(stripped)))
                if len(row) >= 7 and row[2].startswith('20'):
                    started_at = row[2].strip()
                    duration = int(row[3]) if row[3].strip().isdigit() else 0
                    title = row[6].strip() or 'Workout'
                    bw_str = row[7].strip() if len(row) > 7 else ''
                    bodyweight = float(bw_str) if bw_str else None
                    workouts[started_at] = {'title': title, 'duration': duration, 'bodyweight': bodyweight}
            except: pass

        if section == 'sets':
            try:
                row = next(csv.reader(io.StringIO(stripped)))
                if len(row) >= 10 and row[3].strip().isdigit():
                    reps = int(row[3])
                    weight_lbs = float(row[4]) if row[4].strip() else 0
                    weight_kg = round(weight_lbs * 0.453592, 2)
                    exercise = row[8].strip()
                    workout_str = row[9].strip()
                    m = re.match(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\+00:00)\s*(.*?)(?:\s*None)?$', workout_str)
                    if m and exercise and reps > 0:
                        sets.append({'exercise': exercise, 'reps': reps, 'weight_kg': weight_kg, 'workout_date': m.group(1)})
            except: pass

    return workouts, sets

def get_or_create_exercise(supabase, user_id, ex_name, ex_map):
    key = ex_name.lower()
    if key in ex_map:
        return ex_map[key]
    for name, eid in ex_map.items():
        if key in name or name in key:
            return eid
    # Create custom
    res = supabase.table('cwiczenia').insert({'nazwa': ex_name, 'grupa_miesniowa': 'Other', 'typ': 'bilateral', 'custom': True, 'user_id': user_id}).execute()
    eid = res.data[0]['id']
    ex_map[key] = eid
    print(f"  ➕ Nowe ćwiczenie: {ex_name}")
    return eid

def main():
    if len(sys.argv) < 4:
        print(__doc__); sys.exit(1)

    csv_path, email, password = sys.argv[1], sys.argv[2], sys.argv[3]

    print(f"📂 Wczytuję {csv_path}...")
    workouts, sets = parse_csv(csv_path)
    print(f"✅ {len(workouts)} treningów, {len(sets)} serii")

    print(f"🔑 Loguję jako {email}...")
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)
    auth = sb.auth.sign_in_with_password({"email": email, "password": password})
    user_id = auth.user.id
    print(f"✅ Zalogowano ({user_id[:8]}...)")

    ex_res = sb.table('cwiczenia').select('id, nazwa').execute()
    ex_map = {e['nazwa'].lower(): e['id'] for e in ex_res.data}
    print(f"📋 {len(ex_map)} ćwiczeń w bazie")

    sets_by_workout = defaultdict(list)
    for s in sets:
        sets_by_workout[s['workout_date']].append(s)

    sorted_workouts = sorted(workouts.items())
    print(f"\n📥 Importuję {len(sorted_workouts)} treningów...")

    inserted = skipped = 0
    for started_at, info in sorted_workouts:
        workout_sets = sets_by_workout.get(started_at, [])
        if not workout_sets:
            skipped += 1; continue

        duration_s = info['duration']
        try:
            started_dt = datetime.strptime(started_at, '%Y-%m-%d %H:%M:%S+00:00')
            ended_dt = started_dt + timedelta(seconds=duration_s) if duration_s else None
        except:
            skipped += 1; continue

        try:
            w_data = {
                'user_id': user_id, 'nazwa': info['title'],
                'started_at': started_at,
                'ended_at': ended_dt.strftime('%Y-%m-%d %H:%M:%S+00:00') if ended_dt else None,
                'is_draft': False,
            }
            if info['bodyweight']: w_data['bodyweight'] = info['bodyweight']
            w_res = sb.table('treningi').insert(w_data).execute()
            workout_id = w_res.data[0]['id']

            sets_to_insert = []
            for i, s in enumerate(workout_sets):
                ex_id = get_or_create_exercise(sb, user_id, s['exercise'], ex_map)
                sets_to_insert.append({
                    'trening_id': workout_id, 'cwiczenie_id': ex_id,
                    'numer_serii': i + 1, 'powt': s['reps'],
                    'ciezar': s['weight_kg'], 'completed_at': started_at,
                })
            if sets_to_insert:
                sb.table('serie').insert(sets_to_insert).execute()
            inserted += 1
            if inserted % 20 == 0: print(f"  {inserted}/{len(sorted_workouts)}...")
        except Exception as e:
            print(f"  ⚠️ {info['title']} ({started_at[:10]}): {e}")
            skipped += 1

    print(f"\n✅ Import: {inserted} treningów, pominięto {skipped}")

    # Templates
    print("\n📋 Tworzę szablony...")
    templates = {
        'huj0': ['Bench Press','Barbell Jm Press','Kennan Flaps','Bench Supported Single Arm Sagittal Plane Pulldown','Cable Bar Rows','Seated Cable Tricep Pushdown','Cable Flys For Upper Chest','Shoulder Cable Raise','Cuffed Single Arm Cable Chest Fly','Cable Seated Lateral Raise','Cable Seated Bicep Curls'],
        'anterior huj': ['Single Arm Pec Deck','Incline Bench Press','Olymp Cable Tricep Pushdown','Dumbbell Lateral Raise','Single-Leg Extension','Hammer Strength Iso Lateral Shoulder Press','Smith Jm Press','Leg Press','Weighted Decline Ab Crunch','Plank','Treadmill Walking Incline'],
        'posterior huj': ['Single Arm Preacher Curl','Wide-Grip Weighted Pull-Up','Chest Supported Tbar Row','Chest Supported Tbar Kelso Shrug','Hammer Strength Iso-Lateral Low Row','Single Leg Hamstring Curl','Laying Hamstring Curl','Standing Calf Raise','Cuffed Reverse Grip Preacher Curl Machine','Deadlift','Deadhang','Treadmill Walking Incline'],
    }
    for name, exercises in templates.items():
        try:
            tmpl = sb.table('szablony').insert({'user_id': user_id, 'nazwa': name}).execute()
            tmpl_id = tmpl.data[0]['id']
            for i, ex_name in enumerate(exercises):
                ex_id = get_or_create_exercise(sb, user_id, ex_name, ex_map)
                sb.table('szablon_cwiczenia').insert({'szablon_id': tmpl_id, 'cwiczenie_id': ex_id, 'kolejnosc': i, 'domyslne_serie': 3, 'domyslne_powt': 8, 'domyslna_waga': 0}).execute()
            print(f"  ✅ Szablon '{name}' ({len(exercises)} ćwiczeń)")
        except Exception as e:
            print(f"  ⚠️ Szablon {name}: {e}")

    print("\n🎉 Gotowe! Otwórz aplikację i sprawdź Feed oraz Workout → templates.")

if __name__ == '__main__':
    main()
