USE OyunSatisDB;
GO

-- SORGULAMA 1:
-- Geçen ay Türkiye'de en çok satılan ilk 3 oyunun hepsine sahip olanların son eşyaları ve istatistikleri
SELECT 
    E.Ad AS EsyaAdi,
    COUNT(KE_Tum.KullaniciID) AS ToplamSahipSayisi,
    SUM(CASE WHEN U_Tum.Ad = 'Türkiye' THEN 1 ELSE 0 END) AS TurkiyeSahipSayisi
FROM Esya E
JOIN KullaniciEsya KE_Tum ON E.EsyaID = KE_Tum.EsyaID
JOIN Kullanici K_Tum ON KE_Tum.KullaniciID = K_Tum.KullaniciID
JOIN Ilce ILC_Tum ON K_Tum.IlceID = ILC_Tum.IlceID
JOIN Il IL_Tum ON ILC_Tum.IlID = IL_Tum.IlID
JOIN Ulke U_Tum ON IL_Tum.UlkeID = U_Tum.UlkeID
WHERE E.EsyaID IN (
    -- 4. Kullanıcıların sahip olduğu eşyaların ID'lerini bul
    SELECT DISTINCT KE.EsyaID
    FROM KullaniciEsya KE
    WHERE KE.KullaniciID IN (
        -- 3. Türkiye'de en çok satılan o 3 oyunun HEPSİNE sahip olan kullanıcıların ID'leri
        SELECT SA2.KullaniciID
        FROM SatinAlma SA2
        WHERE SA2.UrunID IN (
            -- 1. ve 2. Geçen ay Türkiye'de satılan en çok (TOP 3) oyunu bul
            SELECT TOP 3 SA1.UrunID
            FROM SatinAlma SA1
            JOIN Kullanici K1 ON SA1.KullaniciID = K1.KullaniciID
            JOIN Ilce ILC1 ON K1.IlceID = ILC1.IlceID
            JOIN Il IL1 ON ILC1.IlID = IL1.IlID
            JOIN Ulke U1 ON IL1.UlkeID = U1.UlkeID
            WHERE U1.Ad = 'Türkiye' 
              AND DATEDIFF(MONTH, SA1.SatinAlmaTarihi, GETDATE()) = 1
            GROUP BY SA1.UrunID
            ORDER BY COUNT(*) DESC
        )
        GROUP BY SA2.KullaniciID
        HAVING COUNT(DISTINCT SA2.UrunID) = 3
    )
    -- "Son alınan eşya" şartını MAX() mantığı ile yapıyoruz
    AND KE.EldeEdilmeTarihi = (
        SELECT MAX(KE3.EldeEdilmeTarihi)
        FROM KullaniciEsya KE3
        WHERE KE3.KullaniciID = KE.KullaniciID
    )
)
GROUP BY E.EsyaID, E.Ad
HAVING COUNT(KE_Tum.KullaniciID) > 100;

GO

-- SORGULAMA 2:
SELECT 
    U.Ad AS UlkeAdi,
    COUNT(K.KullaniciID) AS UyeSayisi
FROM Ulke U
JOIN Il IL ON U.UlkeID = IL.UlkeID
JOIN Ilce ILC ON IL.IlID = ILC.IlID
JOIN Kullanici K ON ILC.IlceID = K.IlceID
WHERE K.KullaniciID IN (
    -- X firmasından en az 2 oyun alanlar
    SELECT SA_X.KullaniciID
    FROM SatinAlma SA_X
    JOIN Urun U_X ON SA_X.UrunID = U_X.UrunID
    JOIN Firma F_X ON U_X.YayimciFirmaID = F_X.FirmaID
    WHERE F_X.Ad = 'X'
    GROUP BY SA_X.KullaniciID
    HAVING COUNT(DISTINCT SA_X.UrunID) >= 2
) 
AND K.KullaniciID IN (
    -- Y firmasından en az 3 oyun alanlar
    SELECT SA_Y.KullaniciID
    FROM SatinAlma SA_Y
    JOIN Urun U_Y ON SA_Y.UrunID = U_Y.UrunID
    JOIN Firma F_Y ON U_Y.YayimciFirmaID = F_Y.FirmaID
    WHERE F_Y.Ad = 'Y'
    GROUP BY SA_Y.KullaniciID
    HAVING COUNT(DISTINCT SA_Y.UrunID) >= 3
)
GROUP BY U.Ad
ORDER BY 
    -- 1. ADIM: A ile başlayan ülkeleri (0) yukarıda, başlamayanları (1) aşağıda tut
    CASE WHEN U.Ad LIKE 'A%' THEN 0 ELSE 1 END ASC,
    -- 2. ADIM: A ile başlayanlar için isim bazında A'dan Z'ye alfabetik (ASC)
    CASE WHEN U.Ad LIKE 'A%' THEN U.Ad END ASC,
    -- 3. ADIM: A ile başlamayanlar için üye sayısına göre Büyükten Küçüğe (DESC)
    CASE WHEN U.Ad NOT LIKE 'A%' THEN COUNT(K.KullaniciID) END DESC;
