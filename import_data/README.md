# Import dữ liệu quản lý gà

`chicken_import_2023_2026.json` là toàn bộ sổ ghi chép bán gà 2023 → 5/2026 đã được số hóa,
gồm 36 lứa gà (batches, trong đó 69 đợt bán lẻ), 100 lượt bán gà nòi/gà thịt (cockSales)
và 29 khoản chi chung (expenses) — tổng 251 bản ghi.

## Cách import

1. Mở app → màn **Quản lý gà** → menu ⋮ → **Nhập dữ liệu (JSON)**.
2. Mở file JSON này, copy toàn bộ nội dung và dán vào ô nhập → bấm **Nhập**.
3. Dữ liệu được **thêm vào** (không ghi đè). Chỉ import 1 lần — import lại sẽ bị trùng.

## Định dạng file

```json
{
  "batches": [
    {
      "name": "Bầy 19",
      "incubationDate": "2026-03-05",
      "actualHatchDate": "2026-03-26",
      "quantity": 55,
      "sales": [
        { "date": "2026-04-24", "amount": 660000, "quantity": 20, "note": "Thu, 20 x 33k" },
        { "date": "2026-05-02", "amount": 700000, "quantity": 20, "note": "Chị Bốn" }
      ],
      "vaccinations": [{ "title": "Lasota", "date": "2025-12-04", "completed": true }]
    }
  ],
  "cockSales": [
    { "date": "2025-03-22", "amount": 4000000, "note": "Nhỏ", "category": "fighting" }
  ],
  "expenses": [
    { "date": "2026-01-15", "amount": 92000, "type": "medicine", "note": "Hiệp" }
  ]
}
```

- Một lứa (`batch`) có thể có nhiều đợt bán trong `sales`, thống kê tính theo ngày từng đợt.
- `category`: `fighting` (gà đá/nòi) hoặc `meat` (gà thịt).
- `type` chi phí: `feed` | `medicine` | `electricity` | `water` | `other`.
- Ngày theo định dạng `yyyy-MM-dd`. ID được tự sinh khi import.

## Đối chiếu với sổ gốc

Khớp sổ chính xác:

- 2025: gà nòi 89.000.000, gà con 29.856.000, gà thịt 14.591.000 → tổng thu 133.447.000;
  chi 2025 nhập 1 khoản gộp 55.179.000 (31/12/2025).
- 2026 gà con theo tháng: T1 4.640k, T2 3.150k, T4 2.510k, T5 4.240k đúng bằng sổ.

Các điểm sổ gốc không rõ/không nhất quán, file xử lý như sau:

- Khoản không ghi ngày → gán ngày ước lượng, có chú thích "(ngày ước lượng)".
- Gà thịt 17/3/25 ghi "1..216.000" → lấy 1.016.000 để khớp tổng 9.211.000 của sổ.
- Tháng 3/2026 gà con: chi tiết cộng 5.370.000 nhưng sổ ghi tổng 5.050.000 → giữ chi tiết.
- Gà con thôn 6: dòng "27 con" không rõ giá → tính lùi từ tổng 3.320.000 ra 943.000.
- Bầy 2: sổ ghi bán 32 con nhưng 2 khoản ngày 22/1 cộng 50 con → quantity lấy 50.
- Bầy 16: sổ ghi 29 con nhưng bán 29 + 4 → quantity lấy 33.
- Bầy 17: sổ ghi bán 18/3 nhưng nở 24/3 → giữ ngày bán theo sổ.
- Bầy 8 (nở 17/1/26) sổ không ghi số con → quantity 0, tự sửa lại trong app nếu nhớ.
- Chi tháng 2/2026 sổ ghi tổng 1.935.000 nhưng chi tiết cộng 1.985.000 → giữ chi tiết;
  tương tự tháng 5 (sổ 1.906.000, chi tiết 2.110.000).
- Chi tháng 4/2026 gồm cả lúa (6.050.000 + 3.600.000) mà sổ không tính vào "tổng" tháng → vẫn nhập đủ.
- 2 khoản mua gà (bs Ninh 3.000.000 ngày 1/4/26, gà giống 540.000 ngày 15/2/26) nhập vào chi phí chung loại "Khác".
