USE OyunSatisDB;
GO

-- Oturum tablosunda belirli bir oyunun belirli tarih aralığındaki oturum sayısını sorgulayan
-- sorguyu hızlandıran NONCLUSTERED INDEX (UrunID + BaslamaZamani anahtar, KullaniciID kapsanan sütun).
-- Dosyayı BÖLÜM BÖLÜM çalıştır: her bölümü seçip F5'e bas ve Messages (İletiler) sekmesinden
-- "logical reads" değerini içeren ekran görüntüsünü al.
IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'IX_Oturum_Urun_Baslama' AND object_id = OBJECT_ID('dbo.Oturum'))
    DROP INDEX IX_Oturum_Urun_Baslama ON dbo.Oturum;
GO

-- ===== BÖLÜM 1: INDEX YOKKEN SORGU (1. ekran görüntüsü) =====
SET STATISTICS IO ON;

SELECT UrunID,
       COUNT(*)                       AS OturumSayisi,
       COUNT(DISTINCT KullaniciID)    AS FarkliOyuncuSayisi
FROM Oturum
WHERE UrunID = 3
  AND BaslamaZamani >= '2026-09-01'
  AND BaslamaZamani <  '2026-10-01'
GROUP BY UrunID;
GO

-- ===== BÖLÜM 2: INDEX TANIMI + AYNI SORGU (2. ekran görüntüsü; ikisini birlikte seçip çalıştır) =====
CREATE NONCLUSTERED INDEX IX_Oturum_Urun_Baslama
ON dbo.Oturum (UrunID, BaslamaZamani)
INCLUDE (KullaniciID);
GO

SET STATISTICS IO ON;

SELECT UrunID,
       COUNT(*)                       AS OturumSayisi,
       COUNT(DISTINCT KullaniciID)    AS FarkliOyuncuSayisi
FROM Oturum
WHERE UrunID = 3
  AND BaslamaZamani >= '2026-09-01'
  AND BaslamaZamani <  '2026-10-01'
GROUP BY UrunID;
GO

SET STATISTICS IO OFF;
GO