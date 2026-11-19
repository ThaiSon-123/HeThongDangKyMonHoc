// Beacon điểm danh (docs/ke-hoach-gps-khuon-vien-va-esp32.md §4).
// Nhận mã phòng qua serial (mỗi dòng một mã, 115200 baud), phát qua BLE:
//   - quảng bá: tên "DD-<mã>" (app Android quét ngầm)
//   - GATT: đặc tính CHAR_UUID đọc ra mã (Web Bluetooth)
// Board: ESP32S3 Dev Module, USB CDC On Boot = Disabled khi cắm cổng UART.
#include <BLEDevice.h>
#include <BLEServer.h>

// UUID riêng của dự án; app/web sẽ tìm ESP32 theo UUID này
#define SERVICE_UUID "8f1c0001-5b7e-4c2a-9d3e-6a1f2b3c4d5e"
#define CHAR_UUID    "8f1c0002-5b7e-4c2a-9d3e-6a1f2b3c4d5e"

BLECharacteristic *ch;

// Phát lại quảng bá mỗi khi có kết nối/ngắt, để nhiều máy đọc được lần lượt
class CB : public BLEServerCallbacks {
  void onConnect(BLEServer *s) { BLEDevice::startAdvertising(); }
  void onDisconnect(BLEServer *s) { BLEDevice::startAdvertising(); }
};

void datMa(const String &ma) {
  ch->setValue(ma.c_str());
  BLEAdvertising *a = BLEDevice::getAdvertising();
  a->stop();
  BLEAdvertisementData d;
  d.setFlags(0x06);
  d.setName((String("DD-") + ma).c_str());
  a->setAdvertisementData(d);
  BLEAdvertisementData sr;
  sr.setCompleteServices(BLEUUID(SERVICE_UUID));
  a->setScanResponseData(sr);
  a->start();
}

void setup() {
  Serial.begin(115200);
  BLEDevice::init("DIEMDANH");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new CB());
  BLEService *sv = server->createService(SERVICE_UUID);
  ch = sv->createCharacteristic(CHAR_UUID, BLECharacteristic::PROPERTY_READ);
  sv->start();
  datMa("CHUACO");
  Serial.println("San sang. Go ma roi Enter.");
}

void loop() {
  if (Serial.available()) {
    String ma = Serial.readStringUntil('\n');
    ma.trim();
    if (ma.length() > 0 && ma.length() <= 20) {
      datMa(ma);
      Serial.println("OK " + ma);
    }
  }
}
