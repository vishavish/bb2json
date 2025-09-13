module main

import os
import io
import regex
import json

struct Bookmark {
	link  string
	title string
}

struct BookmarkList {
mut:
	name  string
	items []Bookmark
}

fn main() {
	mut path := ''
	if os.args.len == 2 {
		path = os.args[1]
	} else {
		println('USAGE: bb2json.exe <path to exported brave bookmark file>')
		return
	}

	mut file := os.open(path) or { panic(err) }
	defer { file.close() }

	mut bookmarks := []BookmarkList{}
	mut unlisted := BookmarkList{'Unlisted', []}
	mut temp := BookmarkList{'', []}
	mut reader := io.new_buffered_reader(reader: file)
	mut list_title := ''
	mut has_title := false

	for {
		line := reader.read_line() or {
			if err is io.Eof {
				bookmarks << unlisted
				break
			}
			return
		}

		if line.contains('<H3') && !line.contains('PERSONAL_TOOLBAR_FOLDER') {
			_, list_title = get_line_info(line, true) or { return }
			temp.name = list_title
			has_title = true
			continue
		}

		if line.contains('</DL><p>') {
			if temp.items != [] {
				bookmarks << temp
			}

			temp = BookmarkList{list_title, []}
			has_title = false
			list_title = ''
			continue
		}

		if line.to_lower().contains('href') {
			url, title := get_line_info(line, false) or {
				eprintln('ERROR: ${err}')
				return
			}

			if has_title {
				temp.items << Bookmark{url, title}
			} else {
				unlisted.items << Bookmark{url, title}
			}
		}
	}

	os.write_file('bookmarks.json', json.encode(bookmarks)) or {
		eprintln('Failed to write file: ${err}')
		return
	}
}

fn get_line_info(line string, for_title bool) !(string, string) {
	url_pattern := r'https://([^"]+)'
	title_pattern := r'>([^<]+)'
	mut url_res := []string{}

	if !for_title {
		mut url_re := regex.regex_opt(url_pattern) or { return error('Compiling the pattern.') }

		url_res = url_re.find_all_str(line)
		if url_res.len == 0 {
			return error('Failed to match URL pattern.')
		}
	}

	mut title_re := regex.regex_opt(title_pattern) or { return error('Compiling the pattern.') }

	title_res := title_re.find_all_str(line)
	if title_res.len == 0 {
		return error('Failed to match title pattern.')
	}

	url := if for_title { '' } else { url_res[0] }

	return url, title_res[0].replace_once('>', '')
}
