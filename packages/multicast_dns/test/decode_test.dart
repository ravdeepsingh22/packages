// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:multicast_dns/src/packet.dart';
import 'package:multicast_dns/src/resource_record.dart';

const int _kSrvHeaderSize = 6;

void main() {
  testValidPackages();
  testBadPackages();
  testNonUtf8DomainName();
  // testHexDumpList();
  testPTRRData();
  testSRVRData();
}

void testValidPackages() {
  test('Can decode valid packets', () {
    List<ResourceRecord> result = decodeMDnsResponse(package1)!;
    expect(result, isNotNull);
    expect(result.length, 1);
    IPAddressResourceRecord ipResult = result[0] as IPAddressResourceRecord;
    expect(ipResult.name, 'raspberrypi.local');
    expect(ipResult.address.address, '192.168.1.191');

    result = decodeMDnsResponse(package2)!;
    expect(result.length, 2);
    ipResult = result[0] as IPAddressResourceRecord;
    expect(ipResult.name, 'raspberrypi.local');
    expect(ipResult.address.address, '192.168.1.191');
    ipResult = result[1] as IPAddressResourceRecord;
    expect(ipResult.name, 'raspberrypi.local');
    expect(ipResult.address.address, '169.254.95.83');

    result = decodeMDnsResponse(package3)!;
    expect(result.length, 8);
    expect(result, <ResourceRecord>[
      TxtResourceRecord(
        'raspberrypi [b8:27:eb:03:92:4b]._workstation._tcp.local',
        result[0].validUntil,
        text: '',
      ),
      PtrResourceRecord(
        '_udisks-ssh._tcp.local',
        result[1].validUntil,
        domainName: 'raspberrypi._udisks-ssh._tcp.local',
      ),
      SrvResourceRecord(
        'raspberrypi._udisks-ssh._tcp.local',
        result[2].validUntil,
        target: 'raspberrypi.local',
        port: 22,
        priority: 0,
        weight: 0,
      ),
      TxtResourceRecord(
        'raspberrypi._udisks-ssh._tcp.local',
        result[3].validUntil,
        text: '',
      ),
      PtrResourceRecord('_services._dns-sd._udp.local', result[4].validUntil,
          domainName: '_udisks-ssh._tcp.local'),
      PtrResourceRecord(
        '_workstation._tcp.local',
        result[5].validUntil,
        domainName: 'raspberrypi [b8:27:eb:03:92:4b]._workstation._tcp.local',
      ),
      SrvResourceRecord(
        'raspberrypi [b8:27:eb:03:92:4b]._workstation._tcp.local',
        result[6].validUntil,
        target: 'raspberrypi.local',
        port: 9,
        priority: 0,
        weight: 0,
      ),
      PtrResourceRecord(
        '_services._dns-sd._udp.local',
        result[7].validUntil,
        domainName: '_workstation._tcp.local',
      ),
    ]);

    result = decodeMDnsResponse(packagePtrResponse)!;
    expect(6, result.length);
    expect(result, <ResourceRecord>[
      PtrResourceRecord(
        '_fletch_agent._tcp.local',
        result[0].validUntil,
        domainName: 'fletch-agent on raspberrypi._fletch_agent._tcp.local',
      ),
      TxtResourceRecord(
        'fletch-agent on raspberrypi._fletch_agent._tcp.local',
        result[1].validUntil,
        text: '',
      ),
      SrvResourceRecord(
        'fletch-agent on raspberrypi._fletch_agent._tcp.local',
        result[2].validUntil,
        target: 'raspberrypi.local',
        port: 12121,
        priority: 0,
        weight: 0,
      ),
      IPAddressResourceRecord(
        'raspberrypi.local',
        result[3].validUntil,
        address: InternetAddress('fe80:0000:0000:0000:ba27:ebff:fe69:6e3a'),
      ),
      IPAddressResourceRecord(
        'raspberrypi.local',
        result[4].validUntil,
        address: InternetAddress('192.168.1.1'),
      ),
      IPAddressResourceRecord(
        'raspberrypi.local',
        result[5].validUntil,
        address: InternetAddress('169.254.167.172'),
      ),
    ]);
  });

  // Fixes https://github.com/flutter/flutter/issues/31854
  test('Can decode packages with question, answer and additional', () {
    final List<ResourceRecord> result =
        decodeMDnsResponse(packetWithQuestionAnArCount)!;
    expect(result, isNotNull);
    expect(result.length, 2);
    expect(result, <ResourceRecord>[
      PtrResourceRecord(
        '_______________.____._____',
        result[0].validUntil,
        domainName: '_______________________._______________.____._____',
      ),
      PtrResourceRecord(
        '_______________.____._____',
        result[1].validUntil,
        domainName: '____________________________._______________.____._____',
      ),
    ]);
  });

  // Fixes https://github.com/flutter/flutter/issues/31854
  test('Can decode packages without question and with answer and additional',
      () {
    final List<ResourceRecord> result =
        decodeMDnsResponse(packetWithoutQuestionWithAnArCount)!;
    expect(result, isNotNull);
    expect(result.length, 2);
    expect(result, <ResourceRecord>[
      PtrResourceRecord(
        '_______________.____._____',
        result[0].validUntil,
        domainName: '______________________._______________.____._____',
      ),
      TxtResourceRecord(
        '_______________.____._____',
        result[1].validUntil,
        text: 'model=MacBookPro14,3\nosxvers=18\necolor=225,225,223\n',
      ),
    ]);
  });

  test('Can decode packages with a long text resource', () {
    final List<ResourceRecord> result = decodeMDnsResponse(packetWithLongTxt)!;
    expect(result, isNotNull);
    expect(result.length, 2);
    expect(result, <ResourceRecord>[
      PtrResourceRecord(
        '_______________.____._____',
        result[0].validUntil,
        domainName: '______________________._______________.____._____',
      ),
      TxtResourceRecord(
        '_______________.____._____',
        result[1].validUntil,
        text: (')' * 129) + '\n',
      ),
    ]);
  });
}

void testBadPackages() {
  test('Returns null for invalid packets', () {
    for (List<int> p in <List<int>>[package1, package2, package3]) {
      for (int i = 0; i < p.length; i++) {
        expect(decodeMDnsResponse(p.sublist(0, i)), isNull);
      }
    }
  });
}

void testPTRRData() {
  test('Can read FQDN from PTR data', () {
    expect('sgjesse-macbookpro2 [78:31:c1:b8:55:38]._workstation._tcp.local',
        readFQDN(ptrRData));
    expect('fletch-agent._fletch_agent._tcp.local', readFQDN(ptrRData2));
  });
}

void testSRVRData() {
  test('Can read FQDN from SRV data', () {
    expect('fletch.local', readFQDN(srvRData, _kSrvHeaderSize));
  });
}

void testNonUtf8DomainName() {
  test('Returns non-null for non-utf8 domain name', () {
    final List<ResourceRecord> result = decodeMDnsResponse(nonUtf8Package)!;
    expect(result, isNotNull);
    expect(result[0] is TxtResourceRecord, isTrue);
    final TxtResourceRecord txt = result[0] as TxtResourceRecord;
    expect(txt.name, contains('�'));
  });
}

// One address.
const List<int> package1 = <int>[
  0x00,
  0x00,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00,
  0x00,
  0x01,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x04,
  0xc0,
  0xa8,
  0x01,
  0xbf
];

// Two addresses.
const List<int> package2 = <int>[
  0x00,
  0x00,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x00,
  0x00,
  0x00,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00,
  0x00,
  0x01,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x04,
  0xc0,
  0xa8,
  0x01,
  0xbf,
  0xc0,
  0x0c,
  0x00,
  0x01,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x04,
  0xa9,
  0xfe,
  0x5f,
  0x53
];

// Eight mixed answers.
const List<int> package3 = <int>[
  0x00,
  0x00,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0x20,
  0x5b,
  0x62,
  0x38,
  0x3a,
  0x32,
  0x37,
  0x3a,
  0x65,
  0x62,
  0x3a,
  0x30,
  0x33,
  0x3a,
  0x39,
  0x32,
  0x3a,
  0x34,
  0x62,
  0x5d,
  0x0c,
  0x5f,
  0x77,
  0x6f,
  0x72,
  0x6b,
  0x73,
  0x74,
  0x61,
  0x74,
  0x69,
  0x6f,
  0x6e,
  0x04,
  0x5f,
  0x74,
  0x63,
  0x70,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00,
  0x00,
  0x10,
  0x80,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x01,
  0x00,
  0x0b,
  0x5f,
  0x75,
  0x64,
  0x69,
  0x73,
  0x6b,
  0x73,
  0x2d,
  0x73,
  0x73,
  0x68,
  0xc0,
  0x39,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x0e,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x50,
  0xc0,
  0x68,
  0x00,
  0x21,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x14,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x16,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x3e,
  0xc0,
  0x68,
  0x00,
  0x10,
  0x80,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x01,
  0x00,
  0x09,
  0x5f,
  0x73,
  0x65,
  0x72,
  0x76,
  0x69,
  0x63,
  0x65,
  0x73,
  0x07,
  0x5f,
  0x64,
  0x6e,
  0x73,
  0x2d,
  0x73,
  0x64,
  0x04,
  0x5f,
  0x75,
  0x64,
  0x70,
  0xc0,
  0x3e,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x50,
  0xc0,
  0x2c,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x0c,
  0xc0,
  0x0c,
  0x00,
  0x21,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x09,
  0xc0,
  0x88,
  0xc0,
  0xa3,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x2c
];

const List<int> packagePtrResponse = <int>[
  0x00,
  0x00,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x06,
  0x00,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x5f,
  0x66,
  0x6c,
  0x65,
  0x74,
  0x63,
  0x68,
  0x5f,
  0x61,
  0x67,
  0x65,
  0x6e,
  0x74,
  0x04,
  0x5f,
  0x74,
  0x63,
  0x70,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x1e,
  0x1b,
  0x66,
  0x6c,
  0x65,
  0x74,
  0x63,
  0x68,
  0x2d,
  0x61,
  0x67,
  0x65,
  0x6e,
  0x74,
  0x20,
  0x6f,
  0x6e,
  0x20,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x0c,
  0xc0,
  0x30,
  0x00,
  0x10,
  0x80,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x01,
  0x00,
  0xc0,
  0x30,
  0x00,
  0x21,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x14,
  0x00,
  0x00,
  0x00,
  0x00,
  0x2f,
  0x59,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x1f,
  0xc0,
  0x6d,
  0x00,
  0x1c,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x10,
  0xfe,
  0x80,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xba,
  0x27,
  0xeb,
  0xff,
  0xfe,
  0x69,
  0x6e,
  0x3a,
  0xc0,
  0x6d,
  0x00,
  0x01,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x04,
  0xc0,
  0xa8,
  0x01,
  0x01,
  0xc0,
  0x6d,
  0x00,
  0x01,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x04,
  0xa9,
  0xfe,
  0xa7,
  0xac
];

const List<int> ptrRData = <int>[
  0x27,
  0x73,
  0x67,
  0x6a,
  0x65,
  0x73,
  0x73,
  0x65,
  0x2d,
  0x6d,
  0x61,
  0x63,
  0x62,
  0x6f,
  0x6f,
  0x6b,
  0x70,
  0x72,
  0x6f,
  0x32,
  0x20,
  0x5b,
  0x37,
  0x38,
  0x3a,
  0x33,
  0x31,
  0x3a,
  0x63,
  0x31,
  0x3a,
  0x62,
  0x38,
  0x3a,
  0x35,
  0x35,
  0x3a,
  0x33,
  0x38,
  0x5d,
  0x0c,
  0x5f,
  0x77,
  0x6f,
  0x72,
  0x6b,
  0x73,
  0x74,
  0x61,
  0x74,
  0x69,
  0x6f,
  0x6e,
  0x04,
  0x5f,
  0x74,
  0x63,
  0x70,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00
];

const List<int> ptrRData2 = <int>[
  0x0c,
  0x66,
  0x6c,
  0x65,
  0x74,
  0x63,
  0x68,
  0x2d,
  0x61,
  0x67,
  0x65,
  0x6e,
  0x74,
  0x0d,
  0x5f,
  0x66,
  0x6c,
  0x65,
  0x74,
  0x63,
  0x68,
  0x5f,
  0x61,
  0x67,
  0x65,
  0x6e,
  0x74,
  0x04,
  0x5f,
  0x74,
  0x63,
  0x70,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00
];

const List<int> srvRData = <int>[
  0x00,
  0x00,
  0x00,
  0x00,
  0x2f,
  0x59,
  0x06,
  0x66,
  0x6c,
  0x65,
  0x74,
  0x63,
  0x68,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00
];

const List<int> packetWithQuestionAnArCount = <int>[
  0,
  0,
  2,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  0,
  1,
  15,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  4,
  95,
  95,
  95,
  95,
  5,
  95,
  95,
  95,
  95,
  95,
  0,
  0,
  12,
  0,
  1,
  192,
  12,
  0,
  12,
  0,
  1,
  0,
  0,
  14,
  13,
  0,
  26,
  23,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  12,
  192,
  12,
  0,
  12,
  0,
  1,
  0,
  0,
  14,
  13,
  0,
  31,
  28,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  12,
];

const List<int> packetWithoutQuestionWithAnArCount = <int>[
  0,
  0,
  132,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  15,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  4,
  95,
  95,
  95,
  95,
  5,
  95,
  95,
  95,
  95,
  95,
  0,
  0,
  12,
  0,
  1,
  0,
  0,
  17,
  148,
  0,
  25,
  22,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  12,
  22,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  12,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  28,
  0,
  16,
  0,
  1,
  0,
  0,
  17,
  148,
  0,
  51,
  20,
  109,
  111,
  100,
  101,
  108,
  61,
  77,
  97,
  99,
  66,
  111,
  111,
  107,
  80,
  114,
  111,
  49,
  52,
  44,
  51,
  10,
  111,
  115,
  120,
  118,
  101,
  114,
  115,
  61,
  49,
  56,
  18,
  101,
  99,
  111,
  108,
  111,
  114,
  61,
  50,
  50,
  53,
  44,
  50,
  50,
  53,
  44,
  50,
  50,
  51,
];

// This is the same as packetWithoutQuestionWithAnArCount, but the text
// resource just has a single long string. If the length isn't decoded
// separately from the string, there will be utf8 decoding failures.
const List<int> packetWithLongTxt = <int>[
  0,
  0,
  132,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  15,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  4,
  95,
  95,
  95,
  95,
  5,
  95,
  95,
  95,
  95,
  95,
  0,
  0,
  12,
  0,
  1,
  0,
  0,
  17,
  148,
  0,
  25,
  22,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  12,
  22,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  12,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  95,
  192,
  28,
  0,
  16,
  0,
  1,
  0,
  0,
  17,
  148,
  0,
  51,
  // Long string starts here.
  129,
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, // 16
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, // 32
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, //
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, // 64
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, //
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, //
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, //
  41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41, // 128,
  41, // 129
];

// Package with a domain name that is not valid utf-8.
const List<int> nonUtf8Package = <int>[
  0x00,
  0x00,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0x20,
  0x5b,
  0x62,
  0x38,
  0x3a,
  0x32,
  0x37,
  0x3a,
  0x65,
  0x62,
  0xd2,
  0x30,
  0x33,
  0x3a,
  0x39,
  0x32,
  0x3a,
  0x34,
  0x62,
  0x5d,
  0x0c,
  0x5f,
  0x77,
  0x6f,
  0x72,
  0x6b,
  0x73,
  0x74,
  0x61,
  0x74,
  0x69,
  0x6f,
  0x6e,
  0x04,
  0x5f,
  0x74,
  0x63,
  0x70,
  0x05,
  0x6c,
  0x6f,
  0x63,
  0x61,
  0x6c,
  0x00,
  0x00,
  0x10,
  0x80,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x01,
  0x00,
  0x0b,
  0x5f,
  0x75,
  0x64,
  0x69,
  0x73,
  0x6b,
  0x73,
  0x2d,
  0x73,
  0x73,
  0x68,
  0xc0,
  0x39,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x0e,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x50,
  0xc0,
  0x68,
  0x00,
  0x21,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x14,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x16,
  0x0b,
  0x72,
  0x61,
  0x73,
  0x70,
  0x62,
  0x65,
  0x72,
  0x72,
  0x79,
  0x70,
  0x69,
  0xc0,
  0x3e,
  0xc0,
  0x68,
  0x00,
  0x10,
  0x80,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x01,
  0x00,
  0x09,
  0x5f,
  0x73,
  0x65,
  0x72,
  0x76,
  0x69,
  0x63,
  0x65,
  0x73,
  0x07,
  0x5f,
  0x64,
  0x6e,
  0x73,
  0x2d,
  0x73,
  0x64,
  0x04,
  0x5f,
  0x75,
  0x64,
  0x70,
  0xc0,
  0x3e,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x50,
  0xc0,
  0x2c,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x0c,
  0xc0,
  0x0c,
  0x00,
  0x21,
  0x80,
  0x01,
  0x00,
  0x00,
  0x00,
  0x78,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x09,
  0xc0,
  0x88,
  0xc0,
  0xa3,
  0x00,
  0x0c,
  0x00,
  0x01,
  0x00,
  0x00,
  0x11,
  0x94,
  0x00,
  0x02,
  0xc0,
  0x2c
];
