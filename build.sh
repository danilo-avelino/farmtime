#!/bin/sh
# Gera FarmTime.zip contendo apenas a pasta FarmTime/ (pronta para extrair
# direto em Interface/AddOns). Rodar a cada atualização do addon.
set -e
cd "$(dirname "$0")"
rm -f FarmTime.zip
python3 - <<'PY'
import os, zipfile
with zipfile.ZipFile("FarmTime.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk("FarmTime"):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(root, name)
            info = zipfile.ZipInfo(path, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(path, "rb") as f:
                z.writestr(info, f.read())
PY
echo "FarmTime.zip gerado"
