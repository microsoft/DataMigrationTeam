using System;
using System.Data;
using Microsoft.SqlServer.Server;
using System.Data.SqlTypes;
using System.Data.SqlClient;
using System.Text;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Globalization;
using System.Reflection;
using System.Threading;

/*
Title:  SendSBMsgUDF
Author: Mitch van Huuksloot, 
        Data SQL Ninja Team

The Sample Code below was developed by Microsoft Corporation technical architects.  Because Microsoft must respond to changing market conditions, this document should not be interpreted as an invitation to contract or a commitment on the part of Microsoft.
Microsoft has provided high level guidance in this artifact with the understanding that the reader would undertake detailed design and comprehensive reviews of the overall solution before the solution would be implemented/delivered.  
Microsoft is not responsible for the final implementation undertaken.  
MICROSOFT MAKES NO WARRANTIES, EXPRESS OR IMPLIED WITH RESPECT TO THE INFORMATION CONTAINED HEREIN.  
*/


public class CLRUDF
{
    private const string URI = "https://mvhsbpoc.servicebus.windows.net/tablechange";
    private const string Namespace = "mvhsbpoc.servicebus.windows.net";
    private const string KeyName = "RootManageSharedAccessKey";
    private const string AccountKey = "pjUlu7o4ktS/LJNCzJ9azJTk7n9PV+BEJE4mxS0zX0q=";

    [SqlFunction(Name = "SendSBMsgUDF", DataAccess = DataAccessKind.None, IsDeterministic = false)]
    public static SqlString SendSBMsgUDF(SqlString msgbody)
    {
        DateTime start = DateTime.Now;

         //send message to Service Bus
        try
        {
            string sasToken = GetSasToken();
            WebClient webClient = new WebClient();
            webClient.Headers[HttpRequestHeader.Authorization] = sasToken;
            webClient.Headers[HttpRequestHeader.ContentType] = "application/atom+xml;type=entry;charset=utf-8";
            var body = Encoding.UTF8.GetBytes(msgbody.ToString());
            webClient.UploadData(URI + "/messages", "POST", body);
            string httpmsg;
            int status = GetStatusCode(webClient, out httpmsg);
            if (status < 300) return "Elapsed time: " + DateTime.Now.Subtract(start).TotalMilliseconds.ToString();
            else return status.ToString() + ": " + httpmsg;
        }
        catch (WebException ex)
        {
            return GetErrorFromException(ex);
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    private static string GetSasToken()
    {
        // Set token lifetime to 20 minutes. 
        DateTime origin = new DateTime(1970, 1, 1, 0, 0, 0, 0);
        TimeSpan diff = DateTime.Now.ToUniversalTime() - origin;
        uint tokenExpirationTime = Convert.ToUInt32(diff.TotalSeconds) + (20 * 60);
        string stringToSign = WebUtility.UrlEncode(Namespace) + "\n" + tokenExpirationTime.ToString();
        var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(AccountKey));
        var signature = Convert.ToBase64String(hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign)));
        return string.Format(CultureInfo.InvariantCulture, "SharedAccessSignature sr={0}&sig={1}&se={2}&skn={3}", WebUtility.UrlEncode(Namespace), WebUtility.UrlEncode(signature), tokenExpirationTime, KeyName);
    }

    private static int GetStatusCode(WebClient client, out string statusDescription)
    {
        FieldInfo responseField = client.GetType().GetField("m_WebResponse", BindingFlags.Instance | BindingFlags.NonPublic);
        if (responseField != null)
        {
            HttpWebResponse response = responseField.GetValue(client) as HttpWebResponse;
            if (response != null)
            {
                statusDescription = response.StatusDescription;
                return (int)response.StatusCode;
            }
        }
        statusDescription = null;
        return 0;
    }

    private static string GetErrorFromException(WebException webExcp)
    {
        var exceptionMessage = webExcp.Message;

        try
        {
            var httpResponse = (HttpWebResponse)webExcp.Response;
            var stream = httpResponse.GetResponseStream();
            var memoryStream = new MemoryStream();

            stream.CopyTo(memoryStream);

            var receivedBytes = memoryStream.ToArray();
            exceptionMessage = Encoding.UTF8.GetString(receivedBytes)
              + " (HttpStatusCode "
              + httpResponse.StatusCode.ToString()
              + ")";
        }
        catch (Exception ex)
        {
            exceptionMessage = ex.Message;
        }

        return exceptionMessage;
    }

}