USE OyunSatisDB;
GO

-- SatinAlma tablosuna kayıt eklendiğinde (sp_SepettenOyunSatinAl bu tabloya INSERT yapar) çalışan trigger:
--   Kısım 1: inserted tablosundaki satın almalar kontrol edilir.
--            - Kullanıcının yaşı oyunun yaş sınırından küçükse
--            - Kullanıcının cüzdan bakiyesi toplam tutardan azsa
--            işlem ROLLBACK ile iptal edilir.
--   Kısım 2: Kontrolden geçen satın almaların tutarı Kullanici.Cuzdan değerinden düşülür.
IF OBJECT_ID('dbo.trg_SatinAlma_Kontrol', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_SatinAlma_Kontrol;
GO

CREATE TRIGGER dbo.trg_SatinAlma_Kontrol
ON dbo.SatinAlma
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- KISIM 1a: Yaş sınırı kontrolü
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Kullanici K ON K.KullaniciID = i.KullaniciID
               JOIN Urun      U ON U.UrunID      = i.UrunID
               WHERE ISNULL(U.YasSiniri, 0) > ISNULL(K.Yas, DATEDIFF(YEAR, K.DogumTarihi, GETDATE())))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50010, N'Satın alma iptal edildi: Kullanıcı oyunun yaş sınırını karşılamıyor.', 1;
    END

    -- KISIM 1b: Cüzdan bakiyesi kontrolü
    IF EXISTS (SELECT 1
               FROM Kullanici K
               JOIN (SELECT KullaniciID, SUM(Fiyat) AS Toplam
                     FROM inserted
                     GROUP BY KullaniciID) T ON T.KullaniciID = K.KullaniciID
               WHERE K.Cuzdan < T.Toplam)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50011, N'Satın alma iptal edildi: Cüzdan bakiyesi yetersiz.', 1;
    END

    -- KISIM 2: Satın alma tutarını cüzdandan düş
    UPDATE K
    SET K.Cuzdan = K.Cuzdan - T.Toplam
    FROM Kullanici K
    JOIN (SELECT KullaniciID, SUM(Fiyat) AS Toplam
          FROM inserted
          GROUP BY KullaniciID) T ON T.KullaniciID = K.KullaniciID;
END
GO

-- TEST 1: Bakiyesi yetersiz satın alma -> trigger ROLLBACK yapmalı, kayıt eklenmemeli
DECLARE @K INT, @U INT, @Bakiye DECIMAL(18,2), @Once INT, @Sonra INT;

SELECT TOP 1 @K = KullaniciID, @Bakiye = Cuzdan
FROM Kullanici
WHERE ISNULL(Yas, DATEDIFF(YEAR, DogumTarihi, GETDATE())) >= 18
ORDER BY KullaniciID;

SELECT TOP 1 @U = UrunID FROM Urun ORDER BY ISNULL(YasSiniri, 0), UrunID;

SELECT @Once = COUNT(*) FROM SatinAlma;

BEGIN TRY
    INSERT INTO SatinAlma (KullaniciID, UrunID, Fiyat, UrunAnahtari)
    VALUES (@K, @U, @Bakiye + 1, N'TRG-' + CONVERT(NVARCHAR(36), NEWID()));
END TRY
BEGIN CATCH
    SELECT N'Trigger hatası (beklenen)' AS Sonuc, ERROR_MESSAGE() AS Mesaj;
END CATCH

SELECT @Sonra = COUNT(*) FROM SatinAlma;
SELECT @Once AS SatinAlmaSayisi_Once, @Sonra AS SatinAlmaSayisi_Sonra;   -- ikisi aynı olmalı
GO

-- TEST 2: Yeterli bakiyeli satın alma -> kayıt eklenmeli, cüzdan düşmeli
-- (Veriler bozulmasın diye işlem sonunda ROLLBACK ile geri alınır)
DECLARE @K INT, @U INT;

SELECT TOP 1 @K = KullaniciID
FROM Kullanici
WHERE ISNULL(Yas, DATEDIFF(YEAR, DogumTarihi, GETDATE())) >= 18
ORDER BY KullaniciID;

SELECT TOP 1 @U = UrunID FROM Urun ORDER BY ISNULL(YasSiniri, 0), UrunID;

BEGIN TRANSACTION;

    UPDATE Kullanici SET Cuzdan = 500 WHERE KullaniciID = @K;
    SELECT N'ÖNCE' AS Durum, KullaniciID, ProfilAdi, Cuzdan FROM Kullanici WHERE KullaniciID = @K;

    INSERT INTO SatinAlma (KullaniciID, UrunID, Fiyat, UrunAnahtari)
    VALUES (@K, @U, 50, N'TRG-' + CONVERT(NVARCHAR(36), NEWID()));

    SELECT N'SONRA' AS Durum, KullaniciID, ProfilAdi, Cuzdan FROM Kullanici WHERE KullaniciID = @K;  -- 450 olmalı

ROLLBACK TRANSACTION;
GO