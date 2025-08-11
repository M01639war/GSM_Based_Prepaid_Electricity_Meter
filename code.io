#include <EEPROM.h>
#include <LiquidCrystal_I2C.h>
#include <HardwareSerial.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
HardwareSerial GSM(1);

#define relay 18
#define EEPROM_SIZE 512

int touchThreshold = 30;
int lastTouchState = 0;
char inchar;
int unt_a = 0, unt_b = 0, unt_c = 0, unt_d = 0;
long total_unt = 7;
int price = 0;
long price1 = 0;
int Set = 10;
int pulse = 0;

String phone_no1 = "+918681062816";
String phone_no2 = "+916379292960";

int flag1 = 0, flag2 = 0;

void Read() {
  unt_a = EEPROM.read(1);
  unt_b = EEPROM.read(2);
  unt_c = EEPROM.read(3);
  unt_d = EEPROM.read(4);
  total_unt = unt_d * 1000 + unt_c * 100 + unt_b * 10 + unt_a;
  price1 = total_unt * Set;
}

void Write() {
  unt_d = total_unt / 1000;
  unt_c = (total_unt % 1000) / 100;
  unt_b = (total_unt % 100) / 10;
  unt_a = total_unt % 10;

  EEPROM.write(1, unt_a);
  EEPROM.write(2, unt_b);
  EEPROM.write(3, unt_c);
  EEPROM.write(4, unt_d);
  EEPROM.commit();
}

void IRAM_ATTR onTouch() {
  int touchValue = touchRead(12);
  int touchState = (touchValue < touchThreshold) ? 1 : 0;

  if (touchState == 1 && lastTouchState == 0) {
    pulse++;
    if (pulse > 9) {
      pulse = 0;
      if (total_unt > 0) {
        total_unt--;
      }
      Write();
      Read();
    }
    EEPROM.write(10, pulse);
    EEPROM.commit();
  }

  lastTouchState = touchState;
}

void sendSMS(String number, String msg) {
  GSM.println("AT+CMGF=1");
  GSM.print("AT+CMGS=\"");
  GSM.print(number);
  GSM.println("\"");
  delay(500);
  GSM.println(msg);
  delay(500);
  GSM.write(byte(26));
  delay(5000);
}

void Data() {
  GSM.print("AT+CMGS=\"");
  GSM.print(phone_no1);
  GSM.println("\"\r\n");
  delay(1000);
  GSM.print("Unit:");
  GSM.println(total_unt);
  GSM.print("Price:");
  GSM.println(price1);
  delay(500);
  GSM.write(byte(26));
  delay(5000);
}

void load_on() {
  Write();
  Read();
  digitalWrite(relay, HIGH);
  flag1 = 0;
  flag2 = 0;
}

void setup() {
  Serial.begin(9600);
  GSM.begin(9600, SERIAL_8N1, 16, 17);
  delay(1000);
  EEPROM.begin(EEPROM_SIZE);
  delay(1000);

  pinMode(relay, OUTPUT);
  touchAttachInterrupt(12, onTouch, touchThreshold);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(5, 0);
  lcd.print("WELCOME");
  lcd.setCursor(2, 1);
  lcd.print("Energy Meter");
  delay(1500);
  lcd.clear();

  sendSMS(phone_no1, "Welcome To Energy Meter");

  if (EEPROM.read(50) != 0) {
    Write();
  }

  EEPROM.write(50, 0);
  EEPROM.commit();

  Read();

  if (total_unt > 0) {
    digitalWrite(relay, HIGH);
  }
}

void loop() {
  // SMS Parsing
  String smsBuffer = "";
  while (GSM.available()) {
    char c = GSM.read();
    smsBuffer += c;
    delay(5);
  }

  smsBuffer.trim();

  if (smsBuffer.startsWith("R")) {
    char amountChar = smsBuffer.charAt(1);
    int recharge = 0;

    if (amountChar >= '1' && amountChar <= '4') {
      recharge = (amountChar - '0') * 100;
      price = recharge / Set;
      total_unt += price;
      Write();
      Read();

      sendSMS(phone_no1, "Recharge Done: " + String(recharge));
      sendSMS(phone_no2, "Recharge Done: " + String(recharge));
      load_on();
    }
  } else if (smsBuffer.equalsIgnoreCase("Data")) {
    Data();
  }

  // LCD Display
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 1000) {
    lastUpdate = millis();

    lcd.setCursor(0, 0);
    lcd.print("Unit:");
    lcd.print(total_unt);
    lcd.print("    ");

    lcd.setCursor(0, 1);
    lcd.print("Price:");
    lcd.print(price1);
    lcd.print("    ");

    lcd.setCursor(11, 0);
    lcd.print("Pulse");

    lcd.setCursor(13, 1);
    lcd.print(pulse);
    lcd.print("   ");
  }

  // Alerts
  if (total_unt == 5 && flag1 == 0) {
    flag1 = 1;
    sendSMS(phone_no1, "Balance Low. Please Recharge");
  }

  if (total_unt == 0) {
    digitalWrite(relay, LOW);
    if (flag2 == 0) {
      flag2 = 1;
      sendSMS(phone_no1, "Balance Finished. Please Recharge");
    }
  }
}
