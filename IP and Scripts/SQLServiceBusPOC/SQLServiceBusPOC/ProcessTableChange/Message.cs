using System;
using System.Collections.Generic;

namespace SBMsgFnApp
{
    public class column
    {
        public string colname { get; set; }
        public string value { get; set; }
        public bool IsPK { get; set; }
        public bool NeedsQuote { get; set; }
    }

    public class row
    {
        public List<column> columns { get; set; }

        public row()
        {
            columns = new List<column>();
        }
    }

    public class message
    {
        public string server { get; set; }
        public string action { get; set; }
        public string table { get; set; }
        public List<row> rows { get; set; }
    }
}
