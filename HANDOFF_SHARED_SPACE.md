# Spendly Shared Space - Handoff Note

## Status Saat Ini
Fitur Shared Space sudah berjalan dasar, termasuk:
- Create space (via RPC `create_space_with_owner`)
- Members screen + invite
- Invitation inbox
- Space switcher di Members
- Edit/Hapus space (owner) di Members
- Activity feed
- Filter data by `space_id` di transaksi, akun, budget, analytics, savings

## Error Besar yang Sudah Dibereskan
1. Hero tag conflict FAB (multiple heroes) -> fixed by unique `heroTag`
2. RLS recursion (`space_members`) -> fixed via helper function + policy rewrite SQL
3. `setState() callback returned Future` -> fixed di `transaction_history_screen`
4. Dropdown value assert (space switcher) -> fixed via normalized/safe selected value
5. CircularDependencyError saat create/switch -> fixed dengan menyederhanakan `switchSpace()`
6. `create_space_with_owner` not found -> solved dengan SQL RPC + pemanggilan repository ke RPC

## File SQL Penting (sudah ada di repo)
- `supabase/add_spaces.sql`
- `supabase/fix_space_rls_recursion.sql`
- `supabase/fix_spaces_insert_rls.sql`
- `supabase/fix_create_space_rpc.sql`

## File Flutter yang Sudah Banyak Diubah
- `lib/features/spaces/space_repository.dart`
- `lib/features/spaces/space_notifier.dart`
- `lib/features/spaces/screens/members_screen.dart`
- `lib/features/spaces/widgets/space_switcher_widget.dart`
- `lib/features/navigation/screens/main_tab_screen.dart`
- `lib/shared/services/invitation_service.dart`
- plus beberapa screen dashboard/account/budget/savings untuk FAB heroTag dll

## Permintaan User Terakhir (BELUM dikerjakan)
User minta agar di shared space terlihat **siapa** yang membuat data:
- Transaksi: tampil nama user penginput
- Savings: tampil nama user pada history top-up/withdraw + idealnya creator goal
- Analytics: kontribusi per user (misal total expense/income per anggota)
- Accounts/dompet bersama: jelas bahwa bisa dibuat bersama dan kalau bisa tampil creator/owner

## Copy-Paste Prompt dari User (untuk AI berikutnya)
```
boleh klo tabungan dan anlytc nya juga sama? ada namany user yg di undah atau
begraubung klo usernya add transaksi dan juga bisa bikin accoutn  bersama kan
ke dompet paham kankan? juga sama?
```

## Context Pekerjaan Terakhir yang Sudah Dimulai (BELUM dilanjutkan)
1. Sudah disetujui untuk lanjut implementasi:
   - identitas anggota tampil di Transactions, Savings, Analytics
   - akun/dompet bersama tetap bisa dipakai member di space aktif
2. File yang sudah sempat dieksplor untuk task ini:
   - `lib/shared/models/transaction_model.dart`
   - `lib/features/transaction/transaction_repository.dart`
   - `lib/features/transaction/screens/transaction_history_screen.dart`
   - `lib/features/dashboard/screens/dashboard_screen.dart`
   - `lib/features/savings/savings_deposit_model.dart`
   - `lib/features/savings/savings_repository.dart`
   - `lib/features/savings/screens/goal_detail_screen.dart`
   - `lib/features/analytics/analytics_repository.dart`
   - `lib/features/analytics/screens/analytics_screen.dart`
   - `lib/features/account/account_model.dart`
   - `lib/features/account/account_repository.dart`
   - `lib/features/account/screens/accounts_overview_screen.dart`
3. Belum ada patch final untuk bagian “tampilkan nama user” (masih tahap analisis integrasi).

## Rekomendasi Implementasi Lanjut (untuk AI berikutnya)
1. **Extend model transaksi**
   - Tambah field opsional di `TransactionModel`:
     - `userName`, `userEmail`
   - Parse dari join `profiles(full_name,email)`

2. **Update query repository transaksi/analytics**
   - `transaction_repository.dart` -> select:
     - `select('*, profiles(full_name,email)')`
   - `analytics_repository.dart` -> select yang sama supaya bisa grouping per user

3. **Tampilkan label user di UI transaksi**
   - `transaction_history_screen.dart` dan kartu transaksi dashboard
   - contoh subtitle: `By: {name/email}`

4. **Extend savings deposit model**
   - `SavingsDepositModel` tambah `userName`, `userEmail`
   - `savings_repository.fetchDeposits` select join profiles
   - `goal_detail_screen.dart` tampilkan `By: ...` di tiap row history

5. **(Opsional bagus) creator info untuk SavingsGoal & Account**
   - join profiles saat fetch goals/accounts
   - tampilkan `Created by ...` jika `space_id != null`

6. **Analytics contributor section**
   - Buat metric baru (misal `UserContributionMetric`)
   - Hitung total income/expense per `userId` + label name/email
   - Render section “Kontribusi Anggota” di `analytics_screen.dart`

## Catatan Penting
- Project ini sangat sensitif pada policy RLS Supabase. Kalau ada error 42501/42P17, cek SQL policy aktif dulu.
- Jika RPC baru tidak terbaca, jalankan:
  - `select pg_notify('pgrst', 'reload schema');`

## Validasi terakhir sebelum handoff
- `flutter analyze` terakhir: **No issues found**
