import 'mushaf_models.dart';

/// First ayah of each of the 240 quarters (rub' al-hizb). Four quarters make
/// a hizb and eight make a juz.
const rubStarts = [
  AyahRef(1, 1), AyahRef(2, 26), AyahRef(2, 44), AyahRef(2, 60), // hizb 1
  AyahRef(2, 75), AyahRef(2, 92), AyahRef(2, 106), AyahRef(2, 124), // hizb 2
  AyahRef(2, 142), AyahRef(2, 158), AyahRef(2, 177), AyahRef(2, 189), // hizb 3
  AyahRef(2, 203), AyahRef(2, 219), AyahRef(2, 233), AyahRef(2, 243), // hizb 4
  AyahRef(2, 253), AyahRef(2, 263), AyahRef(2, 272), AyahRef(2, 283), // hizb 5
  AyahRef(3, 15), AyahRef(3, 33), AyahRef(3, 52), AyahRef(3, 75), // hizb 6
  AyahRef(3, 93), AyahRef(3, 113), AyahRef(3, 133), AyahRef(3, 153), // hizb 7
  AyahRef(3, 171), AyahRef(3, 186), AyahRef(4, 1), AyahRef(4, 12), // hizb 8
  AyahRef(4, 24), AyahRef(4, 36), AyahRef(4, 58), AyahRef(4, 74), // hizb 9
  AyahRef(4, 88), AyahRef(4, 100), AyahRef(4, 114), AyahRef(4, 135), // hizb 10
  AyahRef(4, 148), AyahRef(4, 163), AyahRef(5, 1), AyahRef(5, 12), // hizb 11
  AyahRef(5, 27), AyahRef(5, 41), AyahRef(5, 51), AyahRef(5, 67), // hizb 12
  AyahRef(5, 82), AyahRef(5, 97), AyahRef(5, 109), AyahRef(6, 13), // hizb 13
  AyahRef(6, 36), AyahRef(6, 59), AyahRef(6, 74), AyahRef(6, 95), // hizb 14
  AyahRef(6, 111), AyahRef(6, 127), AyahRef(6, 141), AyahRef(6, 151), // hizb 15
  AyahRef(7, 1), AyahRef(7, 31), AyahRef(7, 47), AyahRef(7, 65), // hizb 16
  AyahRef(7, 88), AyahRef(7, 117), AyahRef(7, 142), AyahRef(7, 156), // hizb 17
  AyahRef(7, 171), AyahRef(7, 189), AyahRef(8, 1), AyahRef(8, 22), // hizb 18
  AyahRef(8, 41), AyahRef(8, 61), AyahRef(9, 1), AyahRef(9, 19), // hizb 19
  AyahRef(9, 34), AyahRef(9, 46), AyahRef(9, 60), AyahRef(9, 75), // hizb 20
  AyahRef(9, 93), AyahRef(9, 111), AyahRef(9, 122), AyahRef(10, 11), // hizb 21
  AyahRef(10, 26), AyahRef(10, 53), AyahRef(10, 71), AyahRef(10, 90), // hizb 22
  AyahRef(11, 6), AyahRef(11, 24), AyahRef(11, 41), AyahRef(11, 61), // hizb 23
  AyahRef(11, 84), AyahRef(11, 108), AyahRef(12, 7), AyahRef(12, 30), // hizb 24
  AyahRef(12, 53), AyahRef(12, 77), AyahRef(12, 101), AyahRef(13, 5), // hizb 25
  AyahRef(13, 19), AyahRef(13, 35), AyahRef(14, 10), AyahRef(14, 28), // hizb 26
  AyahRef(15, 1), AyahRef(15, 49), AyahRef(16, 1), AyahRef(16, 30), // hizb 27
  AyahRef(16, 51),
  AyahRef(16, 75),
  AyahRef(16, 90),
  AyahRef(16, 111), // hizb 28
  AyahRef(17, 1), AyahRef(17, 23), AyahRef(17, 50), AyahRef(17, 70), // hizb 29
  AyahRef(17, 99), AyahRef(18, 17), AyahRef(18, 32), AyahRef(18, 51), // hizb 30
  AyahRef(18, 75), AyahRef(18, 99), AyahRef(19, 22), AyahRef(19, 59), // hizb 31
  AyahRef(20, 1), AyahRef(20, 55), AyahRef(20, 83), AyahRef(20, 111), // hizb 32
  AyahRef(21, 1), AyahRef(21, 29), AyahRef(21, 51), AyahRef(21, 83), // hizb 33
  AyahRef(22, 1), AyahRef(22, 19), AyahRef(22, 38), AyahRef(22, 60), // hizb 34
  AyahRef(23, 1), AyahRef(23, 36), AyahRef(23, 75), AyahRef(24, 1), // hizb 35
  AyahRef(24, 21), AyahRef(24, 35), AyahRef(24, 53), AyahRef(25, 1), // hizb 36
  AyahRef(25, 21), AyahRef(25, 53), AyahRef(26, 1), AyahRef(26, 52), // hizb 37
  AyahRef(26, 111),
  AyahRef(26, 181),
  AyahRef(27, 1),
  AyahRef(27, 27), // hizb 38
  AyahRef(27, 56), AyahRef(27, 82), AyahRef(28, 12), AyahRef(28, 29), // hizb 39
  AyahRef(28, 51), AyahRef(28, 76), AyahRef(29, 1), AyahRef(29, 26), // hizb 40
  AyahRef(29, 46), AyahRef(30, 1), AyahRef(30, 31), AyahRef(30, 54), // hizb 41
  AyahRef(31, 22), AyahRef(32, 11), AyahRef(33, 1), AyahRef(33, 18), // hizb 42
  AyahRef(33, 31), AyahRef(33, 51), AyahRef(33, 60), AyahRef(34, 10), // hizb 43
  AyahRef(34, 24), AyahRef(34, 46), AyahRef(35, 15), AyahRef(35, 41), // hizb 44
  AyahRef(36, 28), AyahRef(36, 60), AyahRef(37, 22), AyahRef(37, 83), // hizb 45
  AyahRef(37, 145), AyahRef(38, 21), AyahRef(38, 52), AyahRef(39, 8), // hizb 46
  AyahRef(39, 32), AyahRef(39, 53), AyahRef(40, 1), AyahRef(40, 21), // hizb 47
  AyahRef(40, 41), AyahRef(40, 66), AyahRef(41, 9), AyahRef(41, 25), // hizb 48
  AyahRef(41, 47), AyahRef(42, 13), AyahRef(42, 27), AyahRef(42, 51), // hizb 49
  AyahRef(43, 24), AyahRef(43, 57), AyahRef(44, 17), AyahRef(45, 12), // hizb 50
  AyahRef(46, 1), AyahRef(46, 21), AyahRef(47, 10), AyahRef(47, 33), // hizb 51
  AyahRef(48, 18), AyahRef(49, 1), AyahRef(49, 14), AyahRef(50, 27), // hizb 52
  AyahRef(51, 31), AyahRef(52, 24), AyahRef(53, 26), AyahRef(54, 9), // hizb 53
  AyahRef(55, 1), AyahRef(56, 1), AyahRef(56, 75), AyahRef(57, 16), // hizb 54
  AyahRef(58, 1), AyahRef(58, 14), AyahRef(59, 11), AyahRef(60, 7), // hizb 55
  AyahRef(62, 1), AyahRef(63, 4), AyahRef(65, 1), AyahRef(66, 1), // hizb 56
  AyahRef(67, 1), AyahRef(68, 1), AyahRef(69, 1), AyahRef(70, 19), // hizb 57
  AyahRef(72, 1), AyahRef(73, 20), AyahRef(75, 1), AyahRef(76, 19), // hizb 58
  AyahRef(78, 1), AyahRef(80, 1), AyahRef(82, 1), AyahRef(84, 1), // hizb 59
  AyahRef(87, 1), AyahRef(90, 1), AyahRef(94, 1), AyahRef(100, 9), // hizb 60
];
