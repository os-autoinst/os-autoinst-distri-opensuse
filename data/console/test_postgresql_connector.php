<?php
    $dbconn = pg_connect("host=localhost dbname=openQAdb user=postgres password=postgres")
              or die('Could not connect: ' . pg_last_error());
    $result = pg_query("SELECT * FROM test");
    while($row = pg_fetch_array($result, null, PGSQL_ASSOC)){
        echo $row['entry'], "";
    }
    pg_query("INSERT INTO test (entry) VALUES ('can php write this?')") or die('Query failed: ' . pg_last_error());
?>
