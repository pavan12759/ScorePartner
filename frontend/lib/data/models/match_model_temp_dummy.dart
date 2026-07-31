// Since I cannot rewrite the whole file efficiently in one go without the full content view and avoiding mistakes, 
// I will use `replace_file_content` to append the method inside the class. 
// However, the `write_to_file` tool handles overwrites or new files. 
// I will use `replace_file_content` or `multi_replace` instead.
// Wait, I should use `replace_file_content` to insert the method before the closing brace of MatchModel.
