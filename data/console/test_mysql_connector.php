<?php
    mysql_connect('localhost', 'root', '');
    mysql_select_db('openQAdb');
    $result = mysql_query("SELECT * FROM test");
    while($row = mysql_fetch_array($result)){
        echo $row['entry'];
    }
    mysql_query("INSERT INTO test (entry) VALUE ('can php write this?')");
?>

