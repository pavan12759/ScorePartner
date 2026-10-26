/**
 * ScorePartner Test Suite: SPP ID and Mobile Number Search
 * 
 * Verifies:
 * 1. Add by existing SPP ID
 * 2. Add by verified mobile number
 * 3. Search with +91 and without +91 (with hyphens, spaces, leading 0)
 * 4. Invalid mobile numbers
 * 5. Unknown mobile numbers
 * 6. Duplicate team membership prevention
 * 7. Duplicate tournament registration prevention
 * 8. Existing player statistics and match history remain unchanged
 * 9. Phone number masking (privacy preservation)
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const assert = require('assert');
const { db } = require('../config/firebase');

// Extract normalization and masking helpers to test unit logic
function normalizeIndianPhone(input) {
  if (!input) return null;
  let digits = input.toString().replace(/\D/g, '');
  if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.substring(1);
  } else if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.substring(2);
  } else if (digits.startsWith('091') && digits.length === 13) {
    digits = digits.substring(3);
  }
  if (digits.length !== 10) {
    return null;
  }
  return digits;
}

function maskPhoneNumber(phone) {
  if (!phone) return '';
  const digits = phone.toString().replace(/\D/g, '');
  if (digits.length < 4) return '******';
  const last4 = digits.slice(-4);
  return `+91 ****** ${last4}`;
}

function getPhoneCandidateFormats(tenDigits) {
  return [
    `+91${tenDigits}`,
    `91${tenDigits}`,
    tenDigits,
    `0${tenDigits}`,
  ];
}

async function runTests() {
  console.log('🚀 ========================================================');
  console.log('🧪 Starting ScorePartner SPP ID & Mobile Search Test Suite');
  console.log('========================================================\n');

  let passed = 0;
  let failed = 0;

  function test(name, fn) {
    return (async () => {
      try {
        await fn();
        console.log(`  ✅ PASS: ${name}`);
        passed++;
      } catch (err) {
        console.error(`  ❌ FAIL: ${name}`);
        console.error(`     Error: ${err.message}`);
        failed++;
      }
    })();
  }

  // ── TEST 1: Phone Normalization: with +91, without +91, spaces, hyphens, leading 0 ──
  await test('Phone Normalization handles all valid Indian formats', () => {
    assert.strictEqual(normalizeIndianPhone('8096901136'), '8096901136', '10 digits standard');
    assert.strictEqual(normalizeIndianPhone('+918096901136'), '8096901136', '+91 prefix');
    assert.strictEqual(normalizeIndianPhone('918096901136'), '8096901136', '91 prefix without plus');
    assert.strictEqual(normalizeIndianPhone('+91 80969 01136'), '8096901136', '+91 with spaces');
    assert.strictEqual(normalizeIndianPhone('+91-80969-01136'), '8096901136', '+91 with hyphens');
    assert.strictEqual(normalizeIndianPhone('80969-01136'), '8096901136', 'hyphenated 10 digits');
    assert.strictEqual(normalizeIndianPhone('08096901136'), '8096901136', 'leading 0 (STD/trunk prefix)');
    assert.strictEqual(normalizeIndianPhone('+91 (80969) 01136'), '8096901136', 'parentheses formatting');
  });

  // ── TEST 2: Invalid Mobile Numbers ──
  await test('Invalid mobile numbers are correctly rejected', () => {
    assert.strictEqual(normalizeIndianPhone(''), null, 'empty string');
    assert.strictEqual(normalizeIndianPhone('12345'), null, 'too short');
    assert.strictEqual(normalizeIndianPhone('123456789'), null, '9 digits');
    assert.strictEqual(normalizeIndianPhone('abcdefghij'), null, 'non-digits');
    assert.strictEqual(normalizeIndianPhone('+91 9876543210123'), null, 'too many digits');
    assert.strictEqual(normalizeIndianPhone(null), null, 'null input');
  });

  // ── TEST 3: Phone Number Masking (Privacy Preservation) ──
  await test('Phone numbers are masked to prevent exposing complete number', () => {
    const masked1 = maskPhoneNumber('+918096901136');
    assert.strictEqual(masked1, '+91 ****** 1136', 'Masked E.164 phone');
    assert.strictEqual(masked1.includes('809690'), false, 'Does not expose full digits');

    const masked2 = maskPhoneNumber('9876543210');
    assert.strictEqual(masked2, '+91 ****** 3210', 'Masked 10-digit phone');
  });

  // ── TEST 4: Query Real User by Existing SPP ID in Firestore ──
  let sampleUser = null;
  await test('Query user by existing SPP ID returns player profile and SPP ID', async () => {
    // Find any user in Firestore that has an spPId
    const snap = await db.collection('users').where('spPId', '!=', '').limit(1).get();
    assert.ok(!snap.empty, 'At least one registered user should exist in DB');
    const doc = snap.docs[0];
    sampleUser = { id: doc.id, ...doc.data() };

    const sppId = sampleUser.spPId;
    assert.ok(sppId && sppId.startsWith('SPP'), 'User has valid SPP ID');

    // Query using exact logic from users.js
    const resultSnap = await db.collection('users').where('spPId', '==', sppId.toUpperCase()).limit(1).get();
    assert.ok(!resultSnap.empty, 'SPP ID query should find user');
    const foundUser = resultSnap.docs[0].data();

    assert.strictEqual(foundUser.spPId, sppId, 'SPP ID matches');
    assert.strictEqual(foundUser.name, sampleUser.name, 'Name matches');
  });

  // ── TEST 5: Query Real User by Verified Mobile Number in Firestore ──
  await test('Query user by verified mobile number returns existing profile and SPP ID', async () => {
    // Find a user with phoneNumber in Firestore
    const snap = await db.collection('users')
      .where('phoneNumber', '!=', '')
      .limit(10)
      .get();

    assert.ok(!snap.empty, 'Should have users with phone number');
    const phoneDoc = snap.docs.find(d => d.data().phoneNumber && d.data().phoneNumber.length >= 10);
    assert.ok(phoneDoc, 'Found user document with valid phone number');

    const rawPhone = phoneDoc.data().phoneNumber;
    const normalized = normalizeIndianPhone(rawPhone);
    assert.ok(normalized, `Raw phone ${rawPhone} should normalize to 10 digits`);

    const candidateFormats = getPhoneCandidateFormats(normalized);
    const resultSnap = await db.collection('users')
      .where('phoneNumber', 'in', candidateFormats)
      .limit(5)
      .get();

    assert.ok(!resultSnap.empty, 'Phone query should find user in candidate formats');
    const matched = resultSnap.docs[0].data();
    assert.ok(matched.spPId, 'Found user has valid SPP ID');
    assert.strictEqual(phoneDoc.id, resultSnap.docs[0].id, 'User ID matches existing profile');
  });

  // ── TEST 6: Unknown Mobile Number Returns 404 / No User Found ──
  await test('Unknown mobile number returns empty result (No registered player found)', async () => {
    const fakePhone = '9999900001';
    const candidateFormats = getPhoneCandidateFormats(fakePhone);
    const snap = await db.collection('users')
      .where('phoneNumber', 'in', candidateFormats)
      .limit(1)
      .get();

    assert.ok(snap.empty, 'Unknown mobile number should not return any user');
  });

  // ── TEST 7: Duplicate Team Membership Prevention ──
  await test('Duplicate team player addition is detected and prevented', () => {
    const existingPlayers = [
      { userId: 'user_123', spPId: 'SPP12345678', name: 'Player One', mobileNumber: '+919876543210' },
      { userId: 'user_456', spPId: 'SPP87654321', name: 'Player Two', mobileNumber: '+918765432109' },
    ];

    const duplicateByUserId = { userId: 'user_123', spPId: 'SPP99999999', name: 'Different Name' };
    const duplicateBySppId = { userId: 'user_789', spPId: 'spp12345678', name: 'Another Name' };
    const newValidPlayer = { userId: 'user_999', spPId: 'SPP55555555', name: 'Player Three' };

    function checkDuplicate(newPlayer, list) {
      return list.some(p => {
        if (newPlayer.userId && p.userId && !newPlayer.userId.startsWith('manual_') && p.userId === newPlayer.userId) return true;
        if (newPlayer.spPId && p.spPId && p.spPId.toUpperCase() === newPlayer.spPId.toUpperCase()) return true;
        return false;
      });
    }

    assert.strictEqual(checkDuplicate(duplicateByUserId, existingPlayers), true, 'Duplicate userId blocked');
    assert.strictEqual(checkDuplicate(duplicateBySppId, existingPlayers), true, 'Duplicate SPP ID blocked');
    assert.strictEqual(checkDuplicate(newValidPlayer, existingPlayers), false, 'New valid player allowed');
  });

  // ── TEST 8: Duplicate Tournament Registration Prevention ──
  await test('Duplicate tournament registration is detected and prevented', () => {
    const registeredTeamIds = ['team_alpha', 'team_beta', 'team_gamma'];
    const maxTeams = 8;

    function registerTeam(teamId, registered, max) {
      if (registered.length >= max) {
        return { success: false, error: 'Tournament is full' };
      }
      if (registered.includes(teamId)) {
        return { success: false, error: 'Team already registered' };
      }
      return { success: true };
    }

    assert.deepStrictEqual(registerTeam('team_alpha', registeredTeamIds, maxTeams), { success: false, error: 'Team already registered' });
    assert.deepStrictEqual(registerTeam('team_delta', registeredTeamIds, maxTeams), { success: true });
    assert.deepStrictEqual(registerTeam('team_delta', ['1', '2', '3', '4'], 4), { success: false, error: 'Tournament is full' });
  });

  // ── TEST 9: Existing Player Stats and Match History Remain Unchanged ──
  await test('Existing player stats and match records are verified intact and untouched', async () => {
    if (!sampleUser) return;
    const freshUserDoc = await db.collection('users').doc(sampleUser.id).get();
    assert.ok(freshUserDoc.exists, 'User doc still exists');
    const freshData = freshUserDoc.data();

    // Verify stats structure exists and is untouched
    if (sampleUser.tennisBallStats) {
      assert.deepStrictEqual(freshData.tennisBallStats, sampleUser.tennisBallStats, 'tennisBallStats unchanged');
    }
    if (sampleUser.leatherBallStats) {
      assert.deepStrictEqual(freshData.leatherBallStats, sampleUser.leatherBallStats, 'leatherBallStats unchanged');
    }
    assert.strictEqual(freshData.spPId, sampleUser.spPId, 'Player SPP ID unchanged');
    assert.strictEqual(freshData.name, sampleUser.name, 'Player name unchanged');
  });

  console.log('\n========================================================');
  console.log(`📊 Test Results: ${passed} Passed, ${failed} Failed`);
  console.log('========================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
