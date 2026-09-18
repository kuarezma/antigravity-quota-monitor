---
name: quota-monitor
description: "Antigravity anlık model kotalarını, 5 saatlik ve haftalık havuz kullanım oranlarını ve sıfırlanmaya kalan süreyi dinamik olarak sorgulayan ve canlı görselleştiren uzmanlık becerisi. Kullanıcı '/quota', '/limitler' veya kota durumunu sorduğunda devreye girer."
---

# Antigravity Kota ve Limit Takip Becerisi ⚡

Bu beceri, Antigravity uygulamasının içindeki yerel LanguageServer RPC ve CloudCode servislerine bağlanarak anlık model kotalarını, kalan limit yüzdelerini ve havuz sıfırlanma sürelerini kullanıcıya canlı olarak sunar.

## Kullanım Tetikleyicileri
- Kullanıcı `/quota`, `/limitler` veya `/kotalar` komutunu çalıştırdığında
- Kullanıcı limit durumunu, ne kadar hakkı kaldığını veya ne zaman sıfırlanacağını sorduğunda

## Veri Çekme Yöntemi
```bash
agy-quota --json
```
