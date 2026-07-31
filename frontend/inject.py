import re

try:
    with open(r'd:\ScorePartner\frontend\lib\presentation\screens\profile\profile_screen.dart', 'r', encoding='utf-8') as f:
        profile_content = f.read()

    with open(r'd:\ScorePartner\frontend\lib\presentation\screens\profile\player_profile_screen.dart', 'r', encoding='utf-8') as f:
        player_content = f.read()

    # Extract _buildFullStats through the end of the class from profile_screen.dart
    match = re.search(r'(  Widget _buildFullStats\(PlayerStats stats\).*)$', profile_content, re.MULTILINE | re.DOTALL)
    if not match:
        print("Failed to extract methods from profile_screen.dart")
        exit(1)
        
    extracted_methods = match.group(1)

    # Note that profile_screen.dart class probably ends with '}' which match might skip if not careful, 
    # but re.DOTALL to the end of file will capture it. Let's securely strip the final '}'
    extracted_methods = extracted_methods.rstrip()
    if extracted_methods.endswith('}'):
        extracted_methods = extracted_methods[:-1]

    # Modify _buildRecentMatchesContent to use the passed user parameter instead of current user
    # 1. Change signature
    extracted_methods = extracted_methods.replace('Widget _buildRecentMatchesContent() {', 'Widget _buildRecentMatchesContent(UserModel user) {')
    # 2. Change the userId assignment
    extracted_methods = extracted_methods.replace(
        'final userId = FirebaseAuth.instance.currentUser?.uid;\n    if (userId == null) {\n      return const Center(child: Text(\'Please sign in to view matches\'));\n    }', 
        'final userId = user.uid;\n    if (userId.isEmpty) {\n      return const Center(child: Text(\'No user ID available\'));\n    }'
    )
    
    # Also fix where it's called
    extracted_methods = extracted_methods.replace('_buildRecentMatchesContent(),', '_buildRecentMatchesContent(user),')

    # Remove code from _buildStatsTabs down to the end of the file in player_profile_screen.dart
    match2 = re.search(r'(  Widget _buildStatsTabs\(.*)', player_content, re.DOTALL)
    if not match2:
        print("Failed to locate insertion point in player_profile_screen.dart")
        exit(1)
        
    start_pos = match2.start(1)
    new_player_content = player_content[:start_pos] + extracted_methods + "\n}\n"

    # Now add missing imports at the top of player_profile_screen.dart
    imports_to_add = """
import 'dart:io';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'achievement_share_card.dart';
"""
    
    # check if they exist, if not insert right after other imports
    if 'package:screenshot/screenshot.dart' not in new_player_content:
        import_end = new_player_content.find("class PlayerProfileScreen extends StatefulWidget")
        new_player_content = new_player_content[:import_end] + imports_to_add + "\n" + new_player_content[import_end:]

    with open(r'd:\ScorePartner\frontend\lib\presentation\screens\profile\player_profile_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_player_content)

    print("Successfully ported methods!")

except Exception as e:
    print(f"Error: {e}")
