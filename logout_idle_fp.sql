-- LOGOUT_IDLE_FIX_V1 fingerprint. Konteyner marker=1 sonrasi.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'LOGOUT_IDLE_FIX_V1',
 'app.js Face ID kilidi IDLE_MS 3 dk -> 30 dk. Saha rep telefonu birkac dk cebe koyup donunce her seferinde Face ID istiyordu; Face ID takilirsa tek kacis "sifre ile" -> logoutReload -> /api/auth/logout (revoke) -> ziyaret ortasinda atiliyordu.',
 'Ali Kemal "uzun ziyarette atiliyor" bug''i. Olctum: TTL degil (rep 7g saglam), REVOKE. Iz surdum: login revoke etmiyor -> /api/auth/logout''tan geliyor -> Face ID 3-dk kilit + basarisiz Face ID password-fallback logout. AUTO_LOGOUT_V1 rep''e dokunmuyor (idleMs=0); tek gercek = 3-dk kilit agresifligi. 30 dk staff idle ile ayni; guvenlik korunur.',
 '{"dosya":"app.js","alan":"IDLE_MS (Face ID kilit)","onceki":"3 dk","yeni":"30 dk","marker":"LOGOUT_IDLE_FIX_V1","kok_neden":"3-dk arka-plan kilit -> Face ID fail -> sifre-fallback logoutReload revoke","dokunulmayan":"AUTO_LOGOUT_V1 abs 7g (haftalik re-login, makul)","teshis":"logout_teshis.sql: revoke!=expire"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='LOGOUT_IDLE_FIX_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='LOGOUT_IDLE_FIX_V1';
