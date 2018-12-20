using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Gremlin.Net.Driver;
using Gremlin.Net.Structure.IO.GraphSON;
using Gremlin.Net.Process;
using Newtonsoft.Json;
using System.Configuration;

namespace GremlinCons
{
    class Program
    {
        private static GremlinServer gs;
        private static GremlinClient gc;

        static void InitializeDB()
        {
            string hostname = ConfigurationManager.AppSettings["DocumentServerEndPoint"];
            string authKey = ConfigurationManager.AppSettings["PrimaryKey"];
            string database = ConfigurationManager.AppSettings["Database"];
            string collection = ConfigurationManager.AppSettings["Collection"];
            gs = new GremlinServer(hostname, 443, true, "/dbs/" + database + "/colls/" + collection, authKey);
            gc = new GremlinClient(gs, new GraphSON2Reader(), new GraphSON2Writer(), GremlinClient.GraphSON2MimeType);
        }

        static void DoGremlinCmd(string cmd)
        {
            Task<IReadOnlyCollection<dynamic>> task = null;

            try
            {
                task = gc.SubmitAsync<dynamic>(cmd);
                task.Wait();
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception: " + e.Message);
                Exception inner = e.InnerException;
                while (inner != null)
                {
                    Console.WriteLine("Inner Exception: " + inner.Message);
                    inner = inner.InnerException;
                }
                InitializeDB();
                return;
            }
            foreach (var result in task.Result)
            {
                string output = JsonConvert.SerializeObject(result);
                Console.WriteLine(String.Format("Result:\t{0}", output));
            }
            return;
        }

        static void Main(string[] args)
        {
            InitializeDB();
            string cmd = "";
            DateTime start;
            while (true)
            {
                Console.WriteLine("Enter Gremlin Command");
                cmd = Console.ReadLine();
                if (cmd.ToLower() == "quit" || cmd.ToLower() == "exit") break;
                start = DateTime.Now;
                DoGremlinCmd(cmd);
                Console.WriteLine("Elapsed Time: " + (DateTime.Now.Subtract(start).TotalMilliseconds / 1000.0).ToString() + " seconds\n");
            }
        }
    }
}
