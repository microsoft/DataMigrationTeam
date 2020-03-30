-- This code was borrowed from https://sqlperformance.com/2014/03/sql-performance/configuring-service-broker

-- Create the message types
CREATE MESSAGE TYPE [AsyncRequest] VALIDATION = WELL_FORMED_XML;
CREATE MESSAGE TYPE [AsyncResult]  VALIDATION = WELL_FORMED_XML;
GO
-- Create the contract
CREATE CONTRACT [AsyncContract] 
(
  [AsyncRequest] SENT BY INITIATOR, 
  [AsyncResult]  SENT BY TARGET
);
GO
-- Create the processing queue and service - specify the contract to allow sending to the service
CREATE QUEUE ProcessingQueue;
CREATE SERVICE [ProcessingService] ON QUEUE ProcessingQueue ([AsyncContract]);
GO 
-- Create the request queue and service 
CREATE QUEUE RequestQueue;
CREATE SERVICE [RequestService] ON QUEUE RequestQueue;
GO
-- Create the wrapper procedure for sending messages
CREATE PROCEDURE dbo.SendBrokerMessage 
	@FromService SYSNAME,
	@ToService   SYSNAME,
	@Contract    SYSNAME,
	@MessageType SYSNAME,
	@MessageBody XML
AS
BEGIN
  SET NOCOUNT ON;
 
  DECLARE @conversation_handle UNIQUEIDENTIFIER;
 
  BEGIN TRANSACTION;
 
  BEGIN DIALOG CONVERSATION @conversation_handle
    FROM SERVICE @FromService
    TO SERVICE @ToService
    ON CONTRACT @Contract
    WITH ENCRYPTION = OFF;
 
  SEND ON CONVERSATION @conversation_handle
    MESSAGE TYPE @MessageType(@MessageBody);
 
  COMMIT TRANSACTION;
END
GO
/*
-- Send a request
EXECUTE dbo.SendBrokerMessage
  @FromService = N'RequestService',
  @ToService   = N'ProcessingService',
  @Contract    = N'AsyncContract',
  @MessageType = N'AsyncRequest',
  @MessageBody = N'<AsyncRequest><AccountNumber>12345</AccountNumber></AsyncRequest>';
 
-- Check for message on processing queue
SELECT CAST(message_body AS XML) FROM ProcessingQueue;
GO
*/

-- Create processing procedure for processing queue
CREATE PROCEDURE dbo.ProcessingQueueActivation
AS
BEGIN
  SET NOCOUNT ON;
 
  DECLARE @conversation_handle UNIQUEIDENTIFIER;
  DECLARE @message_body XML;
  DECLARE @message_type_name sysname;
 
  WHILE (1=1)
  BEGIN
    BEGIN TRANSACTION;
 
    WAITFOR
    (
      RECEIVE TOP (1)
        @conversation_handle = conversation_handle,
        @message_body = CAST(message_body AS XML),
        @message_type_name = message_type_name
      FROM ProcessingQueue
    ), TIMEOUT 5000;
 
    IF (@@ROWCOUNT = 0)
    BEGIN
      ROLLBACK TRANSACTION;
      BREAK;
    END
 
    IF @message_type_name = N'AsyncRequest'
    BEGIN
      -- Handle complex long processing here
	  declare @resp nvarchar(max)
	  SELECT @resp = dbo.SendSBMsg(cast(@message_body as nvarchar(max)))
 
      -- Build reply message and send back
      DECLARE @reply_message_body XML = N'<response>' + @resp + '</response>';
 
      SEND ON CONVERSATION @conversation_handle
        MESSAGE TYPE [AsyncResult] (@reply_message_body);
    END
 
    -- If end dialog message, end the dialog
    ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
    BEGIN
      END CONVERSATION @conversation_handle;
    END
 
    -- If error message, log and end conversation
    ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
    BEGIN
      -- Log the error code and perform any required handling here
      -- End the conversation for the error
      END CONVERSATION @conversation_handle;
    END
 
    COMMIT TRANSACTION;
  END
END
GO
-- Create procedure for processing replies to the request queue
CREATE PROCEDURE dbo.RequestQueueActivation
AS
BEGIN
  SET NOCOUNT ON;
 
  DECLARE @conversation_handle UNIQUEIDENTIFIER;
  DECLARE @message_body XML;
  DECLARE @message_type_name sysname;
 
  WHILE (1=1)
  BEGIN
    BEGIN TRANSACTION;
 
    WAITFOR
    (
      RECEIVE TOP (1)
        @conversation_handle = conversation_handle,
        @message_body = CAST(message_body AS XML),
        @message_type_name = message_type_name
      FROM RequestQueue
    ), TIMEOUT 5000;
 
    IF (@@ROWCOUNT = 0)
    BEGIN
      ROLLBACK TRANSACTION;
      BREAK;
    END
 
    IF @message_type_name = N'AsyncResult'
    BEGIN
      SELECT @message_body;
 
      -- Since this is all the work being done, end the conversation to send the EndDialog message
      END CONVERSATION @conversation_handle;
    END
 
    -- If end dialog message, end the dialog
    ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
    BEGIN
       END CONVERSATION @conversation_handle;
    END
 
    -- If error message, log and end conversation
    ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
    BEGIN
       END CONVERSATION @conversation_handle;
    END
 
    COMMIT TRANSACTION;
  END
END
GO

/*
-- Process the message from the processing queue
EXECUTE dbo.ProcessingQueueActivation;
GO
 
-- Check for reply message on request queue
SELECT CAST(message_body AS XML) FROM RequestQueue;
GO
 
-- Process the message from the request queue
EXECUTE dbo.RequestQueueActivation;
GO
*/

-- Alter the processing queue to specify internal activation
ALTER QUEUE ProcessingQueue
    WITH ACTIVATION
    ( 
      STATUS = ON,
      PROCEDURE_NAME = dbo.ProcessingQueueActivation,
      MAX_QUEUE_READERS = 10,
      EXECUTE AS SELF
    );
GO
-- Alter the request queue to specify internal activation
ALTER QUEUE RequestQueue
    WITH ACTIVATION
    ( 
      STATUS = ON,
      PROCEDURE_NAME = dbo.RequestQueueActivation,
      MAX_QUEUE_READERS = 10,
      EXECUTE AS SELF
    );
GO
 
 /*
-- Test automated activation
-- Send a request
 
EXECUTE dbo.SendBrokerMessage
	@FromService = N'RequestService',
	@ToService   = N'ProcessingService',
	@Contract    = N'AsyncContract',
	@MessageType = N'AsyncRequest',
	@MessageBody = N'<message>
<table>foo</table>
<pk>a</pk>
<action>update</action>
<row>
<column name="a">
<inserted>2</inserted>
<deleted>2</deleted>
</column>
<column name="bar">
<inserted>2</inserted>
<deleted>2</deleted>
</column>
<column name="bigstuff">
<inserted>TEST4242</inserted>
<deleted>TEST42</deleted>
</column>
<column name="modified">
<inserted>2019-06-20 4:05:45 PM</inserted>
<deleted>2019-06-20 4:05:45 PM</deleted>
</column>
</row>
<row>
<column name="a">
<inserted>3</inserted>
<deleted>3</deleted>
</column>
<column name="bar">
<inserted>3</inserted>
<deleted>3</deleted>
</column>
<column name="bigstuff">
<inserted>TEST4242</inserted>
<deleted>TEST42</deleted>
</column>
<column name="modified">
<inserted>2019-06-20 4:05:45 PM</inserted>
<deleted>2019-06-20 4:05:45 PM</deleted>
</column>
</row>
</message>';
 
-- Check for message on processing queue 
-- nothing is there because it was automatically processed
SELECT CAST(message_body AS XML) FROM ProcessingQueue;
GO
 
-- Check for reply message on request queue 
-- nothing is there because it was automatically processed
SELECT CAST(message_body AS XML) FROM RequestQueue;
GO
*/