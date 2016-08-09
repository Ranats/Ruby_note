require 'sqlite3'

db = SQLite3::Database.new("db/data.db")

#sql=<<SQL
#CREATE TABLE Aroma(
#  name varchar(255),
#  effect Integer[],
#  scent_group Integer,
#  scent_power Integer,
#  volatile Integer);
#SQL

#db.execute(sql)

sql = "insert into Aroma values('アンジェリカルート',0,0,3,1)"

db.execute(sql)

File.open('db/raw_data') do |file|
  file.each_line do |line|

  end
end

db.close
