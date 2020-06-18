using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Extensions.Logging;
using System.Xml;
using System.Xml.Serialization;
using System.IO;
using System.Data.SqlClient;
using System.Reflection.Emit;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Collections;

/*
Title:  SendSBMsg
Author: Mitch van Huuksloot, 
        Data Migration Jumpstart Team
Copyright © 2019 Microsoft Corporation

The Sample Code below was developed by Microsoft Corporation technical architects.  Because Microsoft must respond to changing market conditions, this document should not be interpreted as an invitation to contract or a commitment on the part of Microsoft.
Microsoft has provided high level guidance in this artifact with the understanding that the reader would undertake detailed design and comprehensive reviews of the overall solution before the solution would be implemented/delivered.  
Microsoft is not responsible for the final implementation undertaken.  
MICROSOFT MAKES NO WARRANTIES, EXPRESS OR IMPLIED WITH RESPECT TO THE INFORMATION CONTAINED HEREIN.  
*/


namespace SBMsgFnApp
{
    public class ColInfo
    {
        public string ColName { get; set; }
        public int NeedsQuote { get; set; }
    }

    public static class MsgProcessorFn
    {
        private const string PKQuery = "select '[' + s.[name] + '].[' + o.[name] + ']', c.[name] " +
                                "from sys.index_columns ic join sys.indexes i on (ic.object_id=i.object_id and ic.index_id=i.index_id) " +
                                    "join sys.columns c on (c.object_id=ic.object_id and ic.column_id=c.column_id) " +
                                    "join sys.objects o on(ic.object_id= o.object_id) " +
                                    "join sys.schemas s on (o.schema_id= s.schema_id) " +
                                "where i.is_primary_key=1 and ic.object_id=object_id('%') order by ic.key_ordinal";
        private const string ColQuey = "select [name], CAST(CASE WHEN system_type_id in (48,52,56,59,60,62,106,108,122,127) then 0 else 1 end as int) from sys.columns where object_id=object_id('%') and is_computed=0 order by column_id";
        private static List<ColInfo> colinf = new List<ColInfo>();

        private static int NeedsQuote(string colname)
        {
            foreach (ColInfo c in colinf)
            {
                if (colname == c.ColName) return c.NeedsQuote;
            }
            return -1;
        }

        [FunctionName("MsgProcessorFn")]
        public static void Run([ServiceBusTrigger("tablechange", "msgprocessor", Connection = "SBCon")]string SbMsg, ILogger log)
        {
#if DEBUG
            DateTime start = DateTime.Now;
#endif
            string[] pks = new string[32];
            int pk = 0;

#if DEBUG
            log.LogInformation($"C# ServiceBus topic trigger function processed message: {SbMsg}");
#endif
            try
            {
                // there is an issue deserializing the XML message since FOR XML PATH used column names as the XML tags around the values
                // therefore the code needs to intercept deserialization exceptions and create the appropriate columns list items
                XmlSerializer xs = new XmlSerializer(typeof(message));
                xs.UnknownElement += xs_UnknownElement;                                                     // add event handler to handle deserialization issues
                StringReader srdr = new StringReader(SbMsg);
                message msg = (message)xs.Deserialize(srdr);                                                // deserialize into message structure
#if DEBUG
                log.LogInformation($"Server: {msg.server}   Action: {msg.action}   Table: {msg.table}");    // log what we now know
#endif

                string conStr = System.Environment.GetEnvironmentVariable($"ConnectionStrings:SQLCon", EnvironmentVariableTarget.Process);
                if (string.IsNullOrEmpty(conStr))                                                           // Azure Functions App Service naming convention
                    conStr = System.Environment.GetEnvironmentVariable($"SQLAZURECONNSTR_SQLCon", EnvironmentVariableTarget.Process);
                string table = null;
                using (SqlConnection con = new SqlConnection(conStr))
                {
                    con.Open();
                    // get primary key columns
                    using (SqlCommand cmd = new SqlCommand(PKQuery.Replace("%", msg.table), con))
                    {
                        using (SqlDataReader rdr = cmd.ExecuteReader(System.Data.CommandBehavior.SingleResult))
                        {
                            while (rdr.Read())
                            {
                                if (table == null) table = rdr.GetString(0);
                                pks[pk++] = rdr.GetString(1);
                            }
                            rdr.Close();
                        }
                    }
                    // get a list of all columns and data types
                    using (SqlCommand cmd = new SqlCommand(ColQuey.Replace("%", msg.table), con))
                    {
                        using (SqlDataReader rdr = cmd.ExecuteReader(System.Data.CommandBehavior.SingleResult))
                        {
                            while (rdr.Read()) colinf.Add(new ColInfo() { ColName = rdr.GetString(0), NeedsQuote = rdr.GetInt32(1) });
                            rdr.Close();
                        }
                    }
                    // if insert - might be an insert or an update - go generate a conditional insert/update
                    if (msg.action == "insert")
                    {
                        // build and execute an upsert
                        foreach (row r in msg.rows)
                        {
                            string sqlstmt = "if exists (select 1 from " + table + " where ";
                            string pkwhere = "";
                            for (int i = 0; i < pk; i++)
                            {
                                foreach (column c in r.columns)
                                {
                                    if (NeedsQuote(pks[i]) == 1) c.NeedsQuote = true;           // not checking if it is computed column
                                    if (i > 0) pkwhere += " and ";
                                    if (c.colname == pks[i])
                                    {
                                        pkwhere += pks[i] + "=";
                                        if (c.NeedsQuote) pkwhere += "'";
                                        pkwhere += c.value;
                                        if (c.NeedsQuote) pkwhere += "'";
                                        c.IsPK = true;
                                    }
                                }
                            }
                            sqlstmt += pkwhere + ")\nupdate " + table + " set ";
                            string update = "";
                            string insertcol = "";
                            string insertval = "";
                            foreach (column c in r.columns)
                            {
                                int nq = NeedsQuote(c.colname);
                                if (nq == 1) c.NeedsQuote = true;
                                if (nq != -1)                                                   // filter out computed columns - which won't show up in column list (explicitly filtered out)
                                {
                                    if (update != "") update += ",";
                                    if (insertcol != "")
                                    {
                                        insertcol += ",";
                                        insertval += ",";
                                    }
                                    if (!c.IsPK)
                                    {
                                        if (c.colname == "PerfTest") update += c.colname + "=sysdatetime()";    // special column for performance testing? Update time to current time.
                                        else
                                        {
                                            update += c.colname + "=";
                                            if (c.NeedsQuote) update += "'";
                                            update += c.value;
                                            if (c.NeedsQuote) update += "'";
                                        }
                                    }
                                    insertcol += c.colname;
                                    if (c.NeedsQuote) insertval += "'";
                                    insertval += c.value;
                                    if (c.NeedsQuote) insertval += "'";
                                }
                            }
                            sqlstmt += update + " where " + pkwhere + "\nelse\ninsert into " + table + " (" + insertcol + ") values (" + insertval + ")";
#if DEBUG
                            log.LogInformation($"SQL Upsert: {sqlstmt}");
#endif
                            using (SqlCommand cmd = new SqlCommand(sqlstmt, con))
                            {
                                cmd.ExecuteNonQuery();
                            }
                        }
                    }
                    // if delete - then generate delete statement (we don't get a delete on an update)
                    else if (msg.action == "delete")
                    {
                        foreach (row r in msg.rows)
                        {
                            string sqlwhere = "";
                            if (pk > 0)                                                         // does the table have a primary key?
                            {
                                for (int i = 0; i < pk; i++)
                                {
                                    foreach (column c in r.columns)
                                    {
                                        if (i > 0) sqlwhere += " and ";
                                        if (NeedsQuote(c.colname) == 1) c.NeedsQuote = true;
                                        if (c.colname == pks[i])
                                        {
                                            sqlwhere += pks[i] + "=";
                                            if (c.NeedsQuote) sqlwhere += "'";
                                            sqlwhere += c.value;
                                            if (c.NeedsQuote) sqlwhere += "'";
                                        }
                                    }
                                }
                            }
                            else                                                                // no primary key - use all columns/values in where clause
                            {
                                foreach (column c in r.columns)
                                {
                                    int nq = NeedsQuote(c.colname);
                                    if (nq == 1) c.NeedsQuote = true;
                                    if (nq != -1)                                               // filter out computed columns - which won't show up in column list (explicitly filtered out)
                                    {
                                        if (sqlwhere.Length == 0) sqlwhere += " and ";
                                        sqlwhere += c.colname + "=";
                                        if (c.NeedsQuote) sqlwhere += "'";
                                        sqlwhere += c.value;
                                        if (c.NeedsQuote) sqlwhere += "'";
                                    }
                                }
                            }
                            string sqlstmt = "delete from " + table + " where " + sqlwhere;
#if DEBUG
                            log.LogInformation($"SQL Delete: {sqlstmt}");
#endif
                            using (SqlCommand cmd = new SqlCommand(sqlstmt, con))
                            {
                                cmd.ExecuteNonQuery();
                            }
                        }
                    }
                    con.Close();
                }
            }
            catch (Exception e)
            {
                log.LogError($"Exception: {e.Message}");
                log.LogError($"Exception Stack: {e.StackTrace}");
            }
#if DEBUG
            log.LogInformation($"Duration (ms): {DateTime.Now.Subtract(start).TotalMilliseconds.ToString()}");
#endif
        }

        private static void xs_UnknownElement(object sender, XmlElementEventArgs e)
        {
            if (e.ObjectBeingDeserialized.GetType() == typeof(row))
            {
                row currow = (row)e.ObjectBeingDeserialized;
                foreach (XmlNode node in e.Element.ChildNodes)
                {
                    if (currow.columns == null) currow.columns = new List<column>();
                    currow.columns.Add(new column() { colname = node.ParentNode.Name, value = node.InnerText, IsPK = false, NeedsQuote = false });
                }
            }
        }
    }
}

