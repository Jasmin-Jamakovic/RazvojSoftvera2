# Sistem preporuke – eDoktor

Dokumentacija sistema preporuke za seminarski rad iz predmeta **Razvoj Softvera 2**.

- **Projekat:** eDoktor (e-Health platforma za zakazivanje pregleda kod ljekara)
- **Broj indeksa:** IB210059
- **Implementacija:** `eDoktor/eDoktor.Services/Recommender/RecommenderService.cs`
- **Endpoint:** `GET /api/doctors/recommended` (vraća personalizovanu listu ljekara za prijavljenog pacijenta)

## 1. Cilj i domena

eDoktor pacijentima preporučuje **ljekare** koji najbolje odgovaraju njihovoj historiji i kontekstu.
Umjesto klasičnih preporuka proizvoda, domena su **usluge (pregledi/konsultacije)**, pa se preporuka
gradi na osnovu medicinskih interesa pacijenta, kvaliteta ljekara, blizine i dostupnosti termina.

Pristup je **content-based (sadržajno zasnovan)** sa dodatnim ne-sadržajnim signalima (ocjena, udaljenost,
dostupnost) kombinovanim u jedinstveni ponderisani rezultat (score). Preporuke su **objašnjive** – uz svaku
preporuku se vraća razlog zašto je ljekar preporučen.

## 2. Algoritam

Konačni rezultat za svakog ljekara `d` u odnosu na pacijenta `p`:

```
score(d) = 0.50 · sim(p, d) + 0.25 · norm(rating(d)) + 0.15 · distDecay(d) + 0.10 · availability(d)
```

Ljekari se sortiraju opadajuće po `score(d)`, a vraća se najboljih `n` (podrazumijevano 10).

### 2.1. sim(p, d) – TF-IDF + kosinusna sličnost (težina 0.50)

Glavna content-based komponenta.

1. **Korpus dokumenata** = svi ljekari. Tekst ljekara (`BuildDoctorText`) se sastoji od:
   - naziva njegovih **specijalizacija**,
   - ključnih riječi iz **biografije** (`Bio`),
   - **grada** klinike.
2. **Profil pacijenta** (`BuildPatientTextAsync`) se gradi iz **stvarne historije** pacijenta:
   - specijalizacija i biografija ljekara kod kojih je pacijent **ranije imao termine**,
   - **dijagnoza, terapija i napomene** iz njegovog elektronskog kartona (`MedicalRecordEntry`).
3. **Tokenizacija** (`Tokenize`): tekst se prebacuje u mala slova, izvlače se riječi dužine ≥ 3
   (podržana su naša slova č/ć/ž/š/đ), a uklanjaju se **stop-riječi** (dvojezična BS/EN lista).
4. **TF-IDF** (`TfIdf`): za svaki token računa se `tf · idf`, gdje je
   `idf(t) = log((1 + N) / (1 + df(t))) + 1` (glatki IDF, `N` = broj ljekara).
5. **Kosinusna sličnost** (`Cosine`) između TF-IDF vektora pacijenta i svakog ljekara daje `sim ∈ [0, 1]`.

### 2.2. norm(rating(d)) – kvalitet ljekara (težina 0.25)

Prosječna ocjena ljekara iz **stvarnih recenzija** (`Review`), skalirana na `[0, 1]` dijeljenjem sa 5.
Računaju se samo recenzije koje nisu obrisane (`!IsDeleted`).

### 2.3. distDecay(d) – blizina (težina 0.15)

`distDecay(d) = exp(-udaljenost_km / 25)`, gdje se udaljenost računa **Haversine** formulom između
koordinata pacijenta i koordinata klinike ljekara. Ako koordinate nisu poznate, vrijednost je `1.0`
(blizina ne kažnjava pacijenta bez lokacije).

### 2.4. availability(d) – dostupnost (težina 0.10)

`1.0` ako ljekar ima bar jedan **slobodan termin u narednih 7 dana** (`TimeSlot` koji nije rezervisan i
počinje u budućnosti), inače `0.0`.

## 3. Objašnjive preporuke

Uz svaku preporuku vraća se polje `RecommendationReason`. Metoda `DominantReason` poredi **ponderisane
doprinose** sve četiri komponente i bira poruku one komponente koja je najviše doprinijela rezultatu:

| Dominantna komponenta | Poruka korisniku |
|---|---|
| sličnost (historija) | „Preporučeno na osnovu vaših prethodnih posjeta i historije" |
| ocjena | „Visoko ocijenjen ljekar (X.X/5)" |
| blizina | „Ljekar u vašoj blizini" |
| dostupnost | „Dostupan u narednih 7 dana" |

Time je zadovoljen zahtjev da recommender **objašnjava** zašto se određeni sadržaj preporučuje.

## 4. Stvarni podaci (nema lažnih signala)

Svi signali koji ulaze u scoring se **stvarno upisuju kroz aplikaciju** i **stvarno koriste**:

- **Historija termina** – upisuje se pri svakom zakazivanju (`InitialAppointmentState`).
- **Recenzije/ocjene** – pacijent ih ostavlja nakon završenog pregleda (`ReviewService`); koriste se i u
  scoring-u i u objašnjenju.
- **Stavke kartona** (dijagnoza/terapija/napomene) – upisuje ljekar.
- **Lokacija i termini** – koordinate pacijenta/klinike i generisani slobodni termini.

Nijedan signal se ne prikuplja a zatim ignoriše – sve četiri komponente (`sim`, `rating`, `dist`, `avail`)
ulaze u konačni `score`.

## 5. Upravljanje modelom i keširanje

- Model je **in-process**: TF-IDF/IDF se računa nad trenutnim korpusom ljekara pri svakom računanju,
  pa nema zastarjelog perzistiranog modela koji treba zasebno održavati.
- Konačna rangirana lista se **kešira u Redis-u** pod ključem `recs:{patientId}` sa TTL od **6 sati**.
- Keš se **invalidira** (`InvalidateAsync`) kada se pojavi novi relevantan događaj (nova recenzija / novi
  termin), tako da naredno računanje odražava nove podatke.

## 6. Cold-start (pacijent bez historije)

Ako pacijent nema historiju (prazan profilni vektor), komponenta sličnosti `sim` postaje 0, pa se rangiranje
prirodno oslanja na **ocjenu + dostupnost + blizinu**. Sistem tako uvijek vraća smislenu listu i za nove
korisnike.

## 7. Usklađenost koda i dokumentacije

Implementacija u `RecommenderService.cs` u potpunosti prati gore opisani pristup: iste težine
(0.50 / 0.25 / 0.15 / 0.10), isti signali, isti algoritam (TF-IDF + kosinusna sličnost), isto keširanje i
isti mehanizam objašnjenja. Konstante težina i TTL definisane su na vrhu klase
(`W_SIM`, `W_RATING`, `W_DIST`, `W_AVAIL`, `CacheTtl`).
