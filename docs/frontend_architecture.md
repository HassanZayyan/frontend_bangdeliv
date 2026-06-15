# Frontend Architecture BangDeliv

Dokumen ini menjelaskan arah refactor Flutter BangDeliv agar mudah diuji dan
mudah dijelaskan saat sidang.

## Prinsip

- UI memakai pola feature-first: kode dikelompokkan berdasarkan flow pengguna,
  bukan hanya berdasarkan tipe file.
- Screen adalah composition layer: membaca state, merender widget, memanggil
  callback, dan melakukan navigasi.
- Logic flow, validasi, mapping label/status, dan orchestration async berada di
  controller/view model Riverpod atau presenter.
- Repository menjadi pintu data untuk screen/provider; service hanya membungkus
  API, storage, realtime, atau plugin eksternal.
- Model/DTO hanya untuk struktur data dan parsing, bukan untuk render widget.

## Struktur Folder

```text
lib/
  core/
    di/             shared dependency injection/provider Riverpod
    widgets/        shared UI primitives
    utils/          helper lintas fitur
  data/
    repositories/   kontrak data dan implementasi repository
    services/       wrapper API/plugin eksternal
  domain/           enum/value object/domain constants
  features/
    auth/
    home/
    orders/
    tracking/
      application/  controller, presenter, view state
      presentation/
        screens/
        widgets/
    driver_orders/
    chatbot/
    shopping/
    addresses/
    profile/
    navigation/
    realtime/
```

## Status Refactor

- `lib/screens` sudah dihapus. Screen utama berada langsung di
  `features/*/presentation/screens`.
- Router utama mengimpor screen langsung dari `lib/features`.
- `lib/providers` sudah dihapus. Shared provider untuk API/service/repository
  berada di `lib/core/di`.
- Provider untuk auth, orders, tracking, driver orders, chatbot, dan realtime
  sudah dipindahkan ke `features/*/application`.
- Provider notifikasi realtime seperti Firebase bootstrap dan chat heads-up
  berada di `features/realtime/application`.
- Widget besar sudah dipisah ke `presentation/widgets` dengan import eksplisit.
  Project tidak memakai Dart `part` untuk menyambungkan screen dan widget.

## Aturan Screen

Screen boleh:

- `ref.watch` provider/controller.
- Merender widget berdasarkan state.
- Mengirim event ke controller.
- Melakukan navigasi setelah action selesai.

Screen tidak boleh:

- Memanggil API/service langsung.
- Menyimpan parsing status/payment/service type.
- Menyimpan kalkulasi route/timeline/fee yang reusable.
- Berisi widget privat besar yang membuat file sulit dibaca.

## Strategi Migrasi

- File lama di `lib/screens`, `lib/providers`, dan `lib/repositories` sudah
  dihapus setelah route, feature code, dan test memakai path arsitektur baru.
- Implementasi utama dipindahkan bertahap ke `lib/features` dan `lib/data`.
- Kode baru di dalam `features` sebaiknya mengimpor provider langsung dari
  `features/*/application` atau `core/di`.
- Setelah setiap slice, jalankan `flutter analyze` dan targeted test sebelum
  lanjut ke slice berikutnya.
