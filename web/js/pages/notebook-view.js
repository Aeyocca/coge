function show_dialog(id, title, html, width, height) {
	var d = $('#'+id);
	if (title) { d.dialog("option", "title", title); }
	if (html) { d.html(html); }
	if (width) {
		d.dialog('option', 'width', width);
		d.dialog('option', 'minWidth', width);
	} else
		width = d.dialog('option', 'width');
	if (height) { d.dialog('option', 'height', height); }
	else { height = d.dialog('option', 'height') };
	var xpos = $(window).width()/2 - width/2;
	var ypos = 100;//$(window).height()/2 - height/2; // hardcode height because jquery not correctly reporting $(window).height()
	d.dialog('option', 'position', [xpos, 100]);
	d.dialog('open');
}

function edit_list_info () {
	$.ajax({
		data: {
			fname: 'edit_list_info',
			lid: NOTEBOOK_ID,
		},
		success : function(data) {
			var obj = JSON.parse(data);
			show_dialog('list_info_edit_box', '', obj.output, '31em');
		},
	});
}

function update_list_info (){
	var name = $('#edit_name').val();
	if (!name) {
		alert('Please specify a name.');
		return;
	}

	var desc = $('#edit_desc').val();
	var type = $('#edit_type').val();

	$.ajax({
		data: {
			fname: 'update_list_info',
			lid: NOTEBOOK_ID,
			name: name,
			desc: desc,
			type: type
		},
		success : function(val) {
			get_list_info();
			$("#list_info_edit_box").dialog('close');
		},
	});
}

function get_list_info() {
	$.ajax({
		data: {
			fname: 'get_list_info',
			lid: NOTEBOOK_ID
		},
		success : function (data) {
			$('#list_info').html(data);
		}
	});
}

function make_list_public () {
	$.ajax({
		data: {
			fname: 'make_list_public',
			lid: NOTEBOOK_ID,
		},
		success : function(val) {
			get_list_info();
		}
	});
}

function make_list_private () {
	$.ajax({
		data: {
			fname: 'make_list_private',
			lid: NOTEBOOK_ID,
		},
		success : function(val) {
			get_list_info();
		},
	});
}

function add_list_items (opts) {
	$.ajax({
		data: {
			fname: 'add_list_items',
			lid: NOTEBOOK_ID,
		},
		success : function(data) {
			var obj = JSON.parse(data);
			show_dialog('list_contents_edit_box', '', obj.output, 650, '600');
		},
	});
}

function add_selected_items (select_id){
	var num_items = $('#' + select_id).find('option:selected').length;
	$('#' + select_id).find('option:selected').each(
		function() {
			var item_spec = $(this).attr("value");
			$.ajax({
				data: {
					fname: 'add_item_to_list',
					lid: NOTEBOOK_ID,
					item_spec : item_spec,
				},
				success :
					function(data) {
						if (data != 1) { alert(data); }
						else {
							if (--num_items == 0) { // only do update on last item
								get_list_contents();
							}
						}
					},
			});
		}
	);
	$("#list_contents_edit_box").dialog('close');
}

function remove_list_item (obj, opts) {
	var item_id = opts.item_id;
	var item_type = opts.item_type;

	$(obj).closest('tr').children().animate({opacity:0});

	$.ajax({
		data: {
			fname: 'remove_list_item',
			lid: NOTEBOOK_ID,
			item_id: item_id,
			item_type: item_type,
		},
		success : function(val) {
			get_list_contents();
		},
	});
}

function get_list_contents() {
	$.ajax({
		data: {
			fname: 'get_list_contents',
			lid: NOTEBOOK_ID,
		},
		success : set_contents
	});
}

function get_annotations() {
	$.ajax({
		data: {
			fname: 'get_annotations',
			lid: NOTEBOOK_ID,
		},
		success : function(data) {
			$('#list_annotations').html(data);
		}
	});
}

function remove_annotation (laid) {
	$.ajax({
		data: {
			fname: 'remove_annotation',
			lid: NOTEBOOK_ID,
			laid: laid,
		},
		success : function(val) {
			get_annotations();
		},
	});
}

function wait_to_search (search_func, search_term) {  //TODO use version in utils
	if (!search_term || search_term.length > 2) {
		pageObj.search_term = search_term;
		if (pageObj.time) {
			clearTimeout(pageObj.time);
		}

		// FIXME: could generalize by passing select id instead of separate search_* functions
		pageObj.time = setTimeout(
			function() {
				search_func(pageObj.search_term);
			},
			500
		);
	}
}

// FIXME: the search functions below are all the same, consolidate?

function search_mystuff () { //TODO migrate to web services
	var search_term = $('#edit_mystuff_search').attr('value');

	$("#wait_mystuff").animate({opacity:1});
	$("#select_mystuff_items").html("<option disabled='disabled'>Searching...</option>");
	pageObj.timestamp['mystuff'] = new Date().getTime();

	$.ajax({
		data: {
			fname: 'search_mystuff',
			lid: NOTEBOOK_ID,
			search_term: search_term,
			timestamp: pageObj.timestamp['mystuff']
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.timestamp == pageObj.timestamp['mystuff']) {
				$("#select_mystuff_items").html(items.html);
				$("#wait_mystuff").animate({opacity:0});
			}
		},
	});
}

function search_genomes () { //TODO migrate to web services
	var search_term = $('#edit_genome_search').val();

	$("#wait_genome").animate({opacity:1});
	$("#select_genome_items").html("<option disabled='disabled'>Searching...</option>");
	pageObj.timestamp['genomes'] = new Date().getTime();

	$.ajax({
		data: {
			fname: 'search_genomes',
			lid: NOTEBOOK_ID,
			search_term: search_term,
			timestamp: pageObj.timestamp['genomes']
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.timestamp == pageObj.timestamp['genomes']) {
				$("#select_genome_items").html(items.html);
				$("#wait_genome").animate({opacity:0});
			}
		},
	});
}

function search_experiments (search_term) { //TODO migrate to web services
	var search_term = $('#edit_experiment_search').val();

	$("#wait_experiment").animate({opacity:1});
	$("#select_experiments_items").html("<option disabled='disabled'>Searching...</option>");
	pageObj.timestamp['experiments'] = new Date().getTime();

	$.ajax({
		data: {
			fname: 'search_experiments',
			lid: NOTEBOOK_ID,
			search_term: search_term,
			timestamp: pageObj.timestamp['experiments']
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.timestamp == pageObj.timestamp['experiments']) {
				$("#select_experiment_items").html(items.html);
				$("#wait_experiment").animate({opacity:0});
			}
		},
	});
}

function search_features () { //TODO migrate to web services
	var search_term = $('#edit_feature_search').attr('value');

	$("#wait_feature").animate({opacity:1});
	$("#select_feature_items").html("<option disabled='disabled'>Searching...</option>");
	pageObj.timestamp['features'] = new Date().getTime();

	$.ajax({
		data: {
			fname: 'search_features',
			lid: NOTEBOOK_ID,
			search_term: search_term,
			timestamp: pageObj.timestamp['features']
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.timestamp == pageObj.timestamp['features']) {
				$("#select_feature_items").html(items.html);
				$("#wait_feature").animate({opacity:0});
			}
		},
	});
}

function search_users (search_term) {
    $.ajax({
        data: {
            jquery_ajax: 1,
            fname: 'search_users',
            search_term: search_term,
            timestamp: new Date().getTime()
        },
        success : function(data) {
            var obj = JSON.parse(data);
            if (obj && obj.items) {
                $("#edit_user").autocomplete({source: obj.items});
                $("#edit_user").autocomplete("search");
            }
        },
    });
}

function search_lists () { //TODO migrate to web services
	var search_term = $('#edit_list_search').attr('value');

	$("#wait_list").animate({opacity:1});
	$("#select_list_items").html("<option disabled='disabled'>Searching...</option>");
	pageObj.timestamp['lists'] = new Date().getTime();

	$.ajax({
		data: {
			fname: 'search_lists',
			lid: NOTEBOOK_ID,
			search_term: search_term,
			timestamp: pageObj.timestamp['lists']
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.timestamp == pageObj.timestamp['lists']) {
				$("#select_list_items").html(items.html);
				$("#wait_list").animate({opacity:0});
			}
		},
	});
}

function delete_list () {
	$.ajax({
		data: {
			fname: 'delete_list',
			lid: NOTEBOOK_ID
		},
		success : function(val) {
			location.reload();
		},
	});
}

function send_list_to() {
	var action = $('#checked_action').val();

	$.ajax({
		data: {
			fname: action,
			lid: NOTEBOOK_ID
		},
		success : function(val) {
			var items = JSON.parse(val);
			if (items.alert) {
				alert(items.alert);
			}
			if (items.url) {
				window.open(items.url, '_blank');
			}
		}
	});
}

function toggle_favorite(img) {
	$.ajax({
		data: {
			fname: 'toggle_favorite',
			nid: NOTEBOOK_ID
		},
		success :  function(val) {
			$(img).attr({ src: (val == '0' ? "picts/star-hollow.png" : "picts/star-full.png") });
		}
	});
}

class Contents {
	constructor(json) {
		this.contents = json.contents;
		this.counts = json.counts;
		this.user_can_edit = json.user_can_edit;
		let div = $('#list_contents');
		let table = $('<table id="list_contents_table" class="dataTable compact hover stripe border-top border-bottom" style="margin:0;width:initial;"></table>').appendTo(div);
		let row = $('<tr></tr>').appendTo($('<thead></thead>').appendTo(table));
		row.append($('<th id="type_col" class="sorting sorting_asc" onclick="contents.sort(\'type\')" style="cursor:pointer;">Type</th>'))
			.append($('<th id="name_col" class="sorting" onclick="contents.sort(\'name\')" style="cursor:pointer;">Name</th>'))
			.append($('<th id="date_col" class="sorting" onclick="contents.sort(\'date\')" style="cursor:pointer;">Date</th>'))
			.append($('<th>Remove</th>'));
		this.tbody = $('<tbody></tbody>').appendTo(table);
		this.sort('type');
		this.build();
		if (json.user_can_edit)
			div.append($('<div class="padded"><span class="coge-button" onClick="add_list_items();"><span class="ui-icon ui-icon-plus"></span>Add</span></div>'));
	}
	build() {
		this.tbody.empty();
		let type = -1;
		let names = ['Genome', 'Experiment', 'Feature', 'Notebook'];
		let pages = ['GenomeInfo', 'ExperimentView', 'FeatView', 'NotebookView'];
		let ids = ['gid', 'eid', 'fid', 'nid'];
		let node_types = [2, 3, 4];
		let num_rows = 0;
		this.contents.forEach(function(row){
			let tr = $('<tr valign="top" class="' + (num_rows % 2 ? 'odd' : 'even') + '"></tr>').appendTo(this.tbody);
			if (this.sort_col == 'type') {
				if (row[0] != type) {
					type = row[0];
					let c = this.counts[row[0]];
					tr.append($('<td align="right" class="title5" rowspan="' + c + '" style="padding-right:10px;white-space:nowrap;font-weight:normal;background-color:white">' + names[type] + 's ' + c + ':</td>'));
				}
			} else
				tr.append($('<td class="title5">' + names[row[0]] + '</td>'));
			tr.append($('<td class="data5"><span class="link" onclick="window.open(\'' + pages[type] + '.pl?' + ids[type] + '=' + row[1] + '\')">' + row[2] + '</span></td>'));
			let td = $('<td class="data5"></td>').appendTo(tr);
			if (row.length > 3 && row[3])
				td.text(row[3]);
			if (this.user_can_edit)
				tr.append($('<td style="padding-left:20px;"><span onClick="remove_list_item(this, {lid: | . $lid . q|, item_type: \'' + node_types[type] + '\', item_id: ' + row[1] + '});" class="link ui-icon ui-icon-closethick"></span></td>'));
			++num_rows;
		}.bind(this));
	}
	sort(col) {
		if (this.sort_col != col) {
			if (this.sort_col)
				$('#' + this.sort_col + '_col').removeClass(this.sort_mult == 1 ? 'sorting_asc' : 'sorting_desc');
			this.sort_col = col;
			this.sort_mult = 1;
			$('#' + this.sort_col + '_col').addClass('sorting_asc');
		} else {
			let td = $('#' + this.sort_col + '_col');
			td.removeClass(this.sort_mult == 1 ? 'sorting_asc' : 'sorting_desc');
			this.sort_mult *= -1;
			td.addClass(this.sort_mult == 1 ? 'sorting_asc' : 'sorting_desc');
		}
		if (col == 'name')
			this.contents.sort(function(a, b) {
				return this.sort_mult * case_insensitive_sort(a[2], b[2]);
			}.bind(this));
		else if (col == 'date')
			this.contents.sort(function(a, b) {
				if (a.length < 4 || !a[3])
					return this.sort_mult * -1;
				if (b.length < 4 || !b[3])
					return this.sort_mult * 1;
				return this.sort_mult * (a[3] < b[3] ? -1 : a[3] > b[3] ? 1 : case_insensitive_sort(a[2], b[2]));
			}.bind(this));
		else
			this.contents.sort(function(a, b) {
				if (a[0] == b[0])
					return case_insensitive_sort(a[2], b[2]);
				return this.sort_mult * (a[0] - b[0]);
			}.bind(this));
		this.build();
	}
}
var contents;
function set_contents(json) {
	if (json.counts[0] + json.counts[1] + json.counts[2] == 0) {
		div.append($('<table class="border-top border-bottom padded note"><tr><td>This notebook is empty.</tr></td></table>'));
		return;
	}
	contents = new Contents(json);
}

function case_insensitive_sort(a, b) {
	let _a = a.toLowerCase();
	if (_a.startsWith('&#x1f512; '))
		_a = _a.substr(6);
	let _b = b.toLowerCase();
	if (_b.startsWith('&#x1f512; '))
		_b = _b.substr(6);
	return _a < _b ? -1 : _a > _b ? 1 : 0;
}
