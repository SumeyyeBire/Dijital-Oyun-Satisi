USE OyunSatisDB;
GO

-- Verilen kullanıcının toplam oynama süresini SAAT cinsinden döndüren fonksiyon
-- Oturum tablosundaki OynamaSuresiDakika dolu ise onu kullanır,
-- boş ise BaslamaZamani - BitisZamani farkından dakika hesaplar.
IF OBJECT_ID('dbo.fn_ToplamOynamaSaati', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_ToplamOynamaSaati;
GO

CREATE FUNCTION dbo.fn_ToplamOynamaSaati (@KullaniciID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @ToplamDakika INT;

    SELECT @ToplamDakika = SUM(
               COALESCE(O.OynamaSuresiDakika,
                        DATEDIFF(MINUTE, O.BaslamaZamani, O.BitisZamani),
                        0))
    FROM Oturum O
    WHERE O.KullaniciID = @KullaniciID;

    RETURN CAST(ISNULL(@ToplamDakika, 0) / 60.0 AS DECIMAL(10,2));
END
GO

-- TEST 1: Tek bir kullanıcı için çağırma (1 numaralı kullanıcı)
SELECT dbo.fn_ToplamOynamaSaati(1) AS ToplamOynamaSaati;
GO

-- TEST 2: Tüm kullanıcılar için tablo halinde sonuç (en çok oynayandan başlayarak ilk 10)
SELECT TOP 10
    K.KullaniciID,
    K.ProfilAdi,
    dbo.fn_ToplamOynamaSaati(K.KullaniciID) AS ToplamOynamaSaati
FROM Kullanici K
ORDER BY ToplamOynamaSaati DESC;
GO




