USE OyunSatisDB;
GO

-- Kullanıcının sepetindeki bir oyunu satın almasını sağlayan prosedür:
--   1) Kullanıcının ülkesindeki fiyatı UrunFiyat tablosundan bulur
--   2) SatinAlma tablosuna yeni satın alma kaydı ekler (INSERT)
--   3) Satın alınan ürünü kullanıcının sepetinden siler (DELETE)
-- Tüm adımlar tek TRANSACTION içindedir, hata olursa hepsi geri alınır.
-- NOT: Bakiye / yaş sınırı kontrolü ve cüzdandan düşme işlemi trigger.sql'deki
--      trg_SatinAlma_Kontrol trigger'ı tarafından yapılır.
IF OBJECT_ID('dbo.sp_SepettenOyunSatinAl', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SepettenOyunSatinAl;
GO

CREATE PROCEDURE dbo.sp_SepettenOyunSatinAl
    @KullaniciID   INT,
    @UrunID        INT,
    @UrunAnahtari  NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fiyat DECIMAL(18,2);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Kullanici WHERE KullaniciID = @KullaniciID)
            THROW 50001, N'Kullanıcı bulunamadı.', 1;

        -- Kullanıcının bulunduğu ülkedeki fiyat
        SELECT @Fiyat = UF.Fiyat
        FROM Kullanici K
        JOIN Ilce ILC ON K.IlceID  = ILC.IlceID
        JOIN Il   IL  ON ILC.IlID  = IL.IlID
        JOIN UrunFiyat UF ON UF.UlkeID = IL.UlkeID
        WHERE K.KullaniciID = @KullaniciID
          AND UF.UrunID     = @UrunID;

        IF @Fiyat IS NULL
            THROW 50002, N'Bu ürün kullanıcının ülkesinde satılmıyor.', 1;

        IF EXISTS (SELECT 1 FROM SatinAlma WHERE KullaniciID = @KullaniciID AND UrunID = @UrunID)
            THROW 50003, N'Kullanıcı bu oyunu zaten satın almış.', 1;

        IF NOT EXISTS (SELECT 1
                       FROM Sepet S
                       JOIN SepetUrun SU ON S.SepetID = SU.SepetID
                       WHERE S.KullaniciID = @KullaniciID AND SU.UrunID = @UrunID)
            THROW 50004, N'Ürün kullanıcının sepetinde bulunmuyor.', 1;

        BEGIN TRANSACTION;

            INSERT INTO SatinAlma (KullaniciID, UrunID, SatinAlmaTarihi, Fiyat, UrunAnahtari)
            VALUES (@KullaniciID, @UrunID, GETDATE(), @Fiyat, @UrunAnahtari);

            DELETE SU
            FROM SepetUrun SU
            JOIN Sepet S ON SU.SepetID = S.SepetID
            WHERE S.KullaniciID = @KullaniciID
              AND SU.UrunID     = @UrunID;

        COMMIT TRANSACTION;

        SELECT N'Satın alma tamamlandı.' AS Sonuc, @Fiyat AS OdenenTutar;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- TEST: Uygun bir kullanıcı ve ürün bulunur, sepete eklenir, prosedür çalıştırılır.
-- (trigger.sql çalıştırıldıktan sonra cüzdan bakiyesi de satın alma tutarı kadar azalır)
DECLARE @K INT, @U INT, @SepetID INT, @Anahtar NVARCHAR(100);

SELECT TOP 1 @K = K.KullaniciID, @U = UF.UrunID
FROM Kullanici K
JOIN Ilce ILC ON K.IlceID = ILC.IlceID
JOIN Il   IL  ON ILC.IlID = IL.IlID
JOIN UrunFiyat UF ON UF.UlkeID = IL.UlkeID
JOIN Urun UR ON UR.UrunID = UF.UrunID
WHERE ISNULL(UR.YasSiniri, 0) <= ISNULL(K.Yas, DATEDIFF(YEAR, K.DogumTarihi, GETDATE()))
  AND NOT EXISTS (SELECT 1 FROM SatinAlma SA WHERE SA.KullaniciID = K.KullaniciID AND SA.UrunID = UF.UrunID)
ORDER BY K.KullaniciID, UF.UrunID;

IF @K IS NULL
BEGIN
    PRINT N'Test için uygun kullanıcı/ürün bulunamadı.';
    RETURN;
END

-- Test hazırlığı: yeterli bakiye ver, sepeti oluştur, ürünü sepete ekle
UPDATE Kullanici SET Cuzdan = CASE WHEN Cuzdan < 1000 THEN 1000 ELSE Cuzdan END WHERE KullaniciID = @K;

IF NOT EXISTS (SELECT 1 FROM Sepet WHERE KullaniciID = @K)
    INSERT INTO Sepet (KullaniciID) VALUES (@K);
SELECT @SepetID = SepetID FROM Sepet WHERE KullaniciID = @K;

IF NOT EXISTS (SELECT 1 FROM SepetUrun WHERE SepetID = @SepetID AND UrunID = @U)
    INSERT INTO SepetUrun (SepetID, UrunID) VALUES (@SepetID, @U);

SET @Anahtar = N'TEST-' + CONVERT(NVARCHAR(36), NEWID());

SELECT N'ÖNCE' AS Durum, K.KullaniciID, K.ProfilAdi, K.Cuzdan,
       (SELECT COUNT(*) FROM SepetUrun WHERE SepetID = @SepetID) AS SepettekiUrunSayisi
FROM Kullanici K WHERE K.KullaniciID = @K;

EXEC dbo.sp_SepettenOyunSatinAl @KullaniciID = @K, @UrunID = @U, @UrunAnahtari = @Anahtar;

SELECT N'SONRA' AS Durum, K.KullaniciID, K.ProfilAdi, K.Cuzdan,
       (SELECT COUNT(*) FROM SepetUrun WHERE SepetID = @SepetID) AS SepettekiUrunSayisi
FROM Kullanici K WHERE K.KullaniciID = @K;

SELECT SA.SatinAlmaID, K.ProfilAdi, UR.Ad AS OyunAdi, SA.Fiyat, SA.UrunAnahtari
FROM SatinAlma SA
JOIN Kullanici K  ON SA.KullaniciID = K.KullaniciID
JOIN Urun      UR ON SA.UrunID      = UR.UrunID
WHERE SA.UrunAnahtari = @Anahtar;
GO