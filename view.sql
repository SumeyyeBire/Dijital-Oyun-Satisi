USE OyunSatisDB;
GO

-- Kullanıcıların ülke/il/ilçe bilgisi, kayıt tarihi, toplam oynama saati (fonksiyondan),
-- oyuncu sınıfı (CASE) ve satın alma özetini tek tabloda gösteren view
-- NOT: Bu view, function.sql içindeki dbo.fn_ToplamOynamaSaati fonksiyonunu kullanır.
--      Önce function.sql çalıştırılmış olmalıdır.
IF OBJECT_ID('dbo.vw_KullaniciOzet', 'V') IS NOT NULL
    DROP VIEW dbo.vw_KullaniciOzet;
GO

CREATE VIEW dbo.vw_KullaniciOzet
AS
SELECT
    K.KullaniciID,
    K.ProfilAdi,
    K.Ad + ' ' + K.Soyad                         AS AdSoyad,
    UL.Ad                                        AS UlkeAdi,
    IL.Ad                                        AS IlAdi,
    ILC.Ad                                       AS IlceAdi,
    FORMAT(K.KayitTarihi, 'dd.MM.yyyy')          AS KayitTarihiMetin,   -- tarih biçimlendirme
    X.ToplamOynamaSaati,                                                -- fonksiyon çağrısı
    CASE                                                                -- CASE kullanımı
        WHEN X.ToplamOynamaSaati >= 25 THEN 'Yoğun Oyuncu'
        WHEN X.ToplamOynamaSaati >= 10 THEN 'Düzenli Oyuncu'
        WHEN X.ToplamOynamaSaati >   0 THEN 'Yeni Oyuncu'
        ELSE 'Hiç Oynamadı'
    END                                          AS OyuncuSinifi,
    ISNULL(S.SatinAlinanOyunSayisi, 0)           AS SatinAlinanOyunSayisi,
    ISNULL(S.ToplamHarcama, 0)                   AS ToplamHarcama
FROM Kullanici K
JOIN Ilce  ILC ON K.IlceID   = ILC.IlceID
JOIN Il    IL  ON ILC.IlID   = IL.IlID
JOIN Ulke  UL  ON IL.UlkeID  = UL.UlkeID
LEFT JOIN (
    SELECT KullaniciID,
           COUNT(*)  AS SatinAlinanOyunSayisi,
           SUM(Fiyat) AS ToplamHarcama
    FROM SatinAlma
    GROUP BY KullaniciID
) S ON S.KullaniciID = K.KullaniciID
CROSS APPLY (SELECT dbo.fn_ToplamOynamaSaati(K.KullaniciID) AS ToplamOynamaSaati) X;
GO

-- TEST: View'ı SatinAlma ve Urun tablolarıyla JOIN'leyerek ülke / oyuncu sınıfı bazında özet
SELECT
    V.UlkeAdi,
    V.OyuncuSinifi,
    U.Ad                         AS OyunAdi,
    COUNT(*)                     AS SatinAlmaSayisi,
    SUM(SA.Fiyat)                AS ToplamTutar,
    AVG(V.ToplamOynamaSaati)     AS OrtOynamaSaati
FROM dbo.vw_KullaniciOzet V
JOIN SatinAlma SA ON V.KullaniciID = SA.KullaniciID
JOIN Urun      U  ON SA.UrunID     = U.UrunID
GROUP BY V.UlkeAdi, V.OyuncuSinifi, U.Ad
ORDER BY V.UlkeAdi, SatinAlmaSayisi DESC;
GO