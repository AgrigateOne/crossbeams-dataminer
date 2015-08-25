#!/usr/bin/env ruby

require 'rubygems'
require 'pg_query'

# PgQ methods: [:aliases, :deparse, :filter_columns, :fingerprint, :param_refs, :parsetree, :query, :tables, :truncate, :warnings]
# prsetre returns a Hash...

s = "SELECT * FROM users;"
ns = ARGV[0]
s = ns if ns

 def get_column_name(restarget)
   if restarget['name']
     restarget['name']
   else
     if restarget['val']['FUNCCALL']
       restarget['val']['FUNCCALL']['funcname']
     else
       fld = restarget['val']['COLUMNREF']['fields'].first
       if fld.is_a? String
         fld
       else
         fld.keys[0]
       end
     end
   end
 end

pq = PgQuery.parse(s)
puts '---'
puts "ALIASES        : #{pq.aliases}"
puts "FILTER COLUMNS : #{pq.filter_columns}"
puts "FINGER         : #{pq.fingerprint}"
puts "PARAM REFS     : #{pq.param_refs}"
puts "TABLES         : #{pq.tables}"
puts "WARN           : #{pq.warnings}"
puts '---'
#puts pq.parsetree.public_methods(false).sort.inspect
puts "PARSETREE:"

pt = pq.parsetree
puts "LEN : #{pt.length}"
puts "SEL?: #{pt[0].has_key?('SELECT')}"
puts "TGT : #{pt[0]['SELECT']['targetList'].length}"
pt[0]['SELECT']['targetList'].each do |tgt|
  puts "TGT : #{tgt}"
end

puts pt.inspect.gsub('{', "\n{").gsub('[', "\n[").gsub('}', "\n}").gsub(']', "\n]")

puts "COLS: #{pt[0]['SELECT']['targetList'].map {|r| get_column_name(r['RESTARGET']) }.join(',')}"
#[0]['RESTARGET']['val']['COLUMNREF']['fields']

__END__
./check_pg.rb "SELECT * FROM users;"
./check_pg.rb "SELECT id, name FROM users;"
./check_pg.rb "SELECT count(*) FROM users;"
./check_pg.rb "SELECT extract('year' from created_at) FROM users;"
./check_pg.rb "SELECT extract('year' from created_at) as testo FROM users;"
./check_pg.rb "select u.*, b.name FROM users u JOIN branches b ON b.id = u.br_id;" ------- problems with columns here....

[
{"SELECT"=>
{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>
[
{"RESTARGET"=>
{"name"=>nil, "indirection"=>nil, "val"=>
{"COLUMNREF"=>
{"fields"=>
[
{"A_STAR"=>
{
}
}
], "location"=>7
}
}, "location"=>7
}
}
], "fromClause"=>
[
{"RANGEVAR"=>
{"schemaname"=>nil, "relname"=>"users", "inhOpt"=>2, "relpersistence"=>"p", "alias"=>nil, "location"=>14
}
}
], "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>false, "larg"=>nil, "rarg"=>nil
}
}
]

