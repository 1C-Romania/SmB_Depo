////////////////////////////////////////////////////////////////////////////////
// Information center messages processing.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Receives message handler list which this subsystem is processing.
// 
// Parameters:
//  Handlers - ValueTable - for the field content see MessageExchange.NewMessageHandlersTable
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	AddMessageChannelHandler("InformationCenter\Inaccessibility\Insert",        InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\Inaccessibility\Delete",          InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\News\Insert",              InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\News\Delete",                InformationCenterMessagesMessageHandler, Handlers);
	
EndProcedure

// Executes the message body data processor from channel according to the current message channel procedure
//
// Parameters:
//  <MessagesChanel> (IsRequired). Type:String. Identifier of the message channel from which the message was received.
//  <MessageBody> (IsRequired). Type: Custom. Message body received from channel which must be processed.
//  <Sender> (IsRequired). Type: ExchangePlanRef.MessageExchange. End point which is message sender.
//
Procedure ProcessMessage(Val MessageChannel, Val MessageBody, Val Sender) Export
	
	If MessageChannel = "InformationCenter\Inaccessibility\Insert" Then
		ProcessInaccessibility(MessageBody);
	ElsIf MessageChannel = "InformationCenter\Inaccessibility\Delete" Then
		If MessageBody.Property("ID") Then 
			DeleteInformationCenterData(MessageBody.ID);
		EndIf;
	ElsIf MessageChannel = "InformationCenter\News\Insert" Then
		ProcessNews(MessageBody);
	ElsIf MessageChannel = "InformationCenter\News\Delete" Then
		If MessageBody.Property("ID") Then 
			DeleteInformationCenterData(MessageBody.ID);
		EndIf;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Adds the channel handler.
//
Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

// Processes the unavailability.
//
// Parameters:
// MessageBody - Structure - message body.
//
Procedure ProcessInaccessibility(MessageBody)
	
	Object = GetDataByID(MessageBody.ID);
	If Object = Undefined Then
		CreateInaccessibility(MessageBody);
	Else
		UpdateInaccessibility(Object, MessageBody);
	EndIf;
	
EndProcedure

// Creates the unavailability in the catalog of the information center general data.
//
// Parameters:
// MessageBody - Structure - message body.
//
Procedure CreateInaccessibility(MessageBody)
	
	Inaccessibility = Catalogs.InformationCenterCommonData.CreateItem();
	Inaccessibility.SetNewCode();
	
	Inaccessibility.ID             = MessageBody.ID;
	Inaccessibility.Description              = GenerateInaccessibilityHeader(MessageBody.Description, MessageBody.ActualityBeginningDate, MessageBody.ActualityEndingDate);
	Inaccessibility.Date                      = MessageBody.Date;
	Inaccessibility.ActualityBeginningDate    = MessageBody.ActualityBeginningDate - (60 * 60 * 24);
	Inaccessibility.ActualityEndingDate = MessageBody.ActualityEndingDate;
	Inaccessibility.Criticality               = MessageBody.Criticality;
	If MessageBody.Property("HTMLText") Then 
		Inaccessibility.HTMLText = MessageBody.HTMLText;
	EndIf;
	If MessageBody.Property("Attachments") Then 
		Inaccessibility.Attachments = New ValueStorage(MessageBody.Attachments);
	EndIf;
	If MessageBody.Property("ExternalRef") Then 
		Inaccessibility.ExternalRef	= MessageBody.ExternalRef;
	EndIf;
	If MessageBody.Property("InformationType") Then 
		Inaccessibility.InformationType = InformationCenterServer.GetInformationTypeRef(MessageBody.InformationType);
	Else
		Inaccessibility.InformationType = InformationCenterServer.GetInformationTypeRef("Inaccessibility");
	EndIf;
	
	Inaccessibility.Write();
	
EndProcedure	

// Updates the unavailability.
//
// Parameters:
// Inaccessibility - CatalogRef.InformationCenterCommonData - ref to the unavailability.
// MessageBody - Structure - message body.
//
Procedure UpdateInaccessibility(Inaccessibility, MessageBody)
	
	Inaccessibility.InformationType             = InformationCenterServer.GetInformationTypeRef("Inaccessibility");
	Inaccessibility.ID             = MessageBody.ID;
	Inaccessibility.Description              = GenerateInaccessibilityHeader(MessageBody.Description, MessageBody.ActualityBeginningDate, MessageBody.ActualityEndingDate);
	Inaccessibility.Date                      = MessageBody.Date;
	Inaccessibility.ActualityBeginningDate    = MessageBody.ActualityBeginningDate - (60 * 60 * 24);
	Inaccessibility.ActualityEndingDate = MessageBody.ActualityEndingDate;
	Inaccessibility.Criticality               = MessageBody.Criticality;
	Inaccessibility.DeletionMark           = False;
	If MessageBody.Property("HTMLText") Then 
		Inaccessibility.HTMLText = MessageBody.HTMLText;
	EndIf;
	If MessageBody.Property("Attachments") Then 
		Inaccessibility.Attachments = New ValueStorage(MessageBody.Attachments);
	EndIf;
	If MessageBody.Property("ExternalRef") Then 
		Inaccessibility.ExternalRef = MessageBody.ExternalRef;
	EndIf;
	Inaccessibility.Write();
	
EndProcedure	

// Processes the news.
//
// Parameters:
// MessageBody - Structure - message body.
//
Procedure ProcessNews(MessageBody)
	
	Object = GetDataByID(MessageBody.ID);
	If Object = Undefined Then
		CreateNews(MessageBody);
	Else
		UpdateNews(Object, MessageBody);
	EndIf;
	
EndProcedure

// Creates a news in the catalog of the information center general data.
//
// Parameters:
// MessageBody - Structure - message body.
//
Procedure CreateNews(MessageBody)
	
	News = Catalogs.InformationCenterCommonData.CreateItem();
	News.SetNewCode();
	
	News.ID             = MessageBody.ID;
	News.Description              = TrimAll(MessageBody.Description);
	News.Date                      = MessageBody.Date;
	News.ActualityBeginningDate    = MessageBody.ActualityBeginningDate;
	News.ActualityEndingDate = MessageBody.ActualityEndingDate;
	News.Criticality               = MessageBody.Criticality;
	If MessageBody.Property("HTMLText") Then 
		News.HTMLText = MessageBody.HTMLText;
	EndIf;
	If MessageBody.Property("Attachments") Then 
		News.Attachments = New ValueStorage(MessageBody.Attachments);
	EndIf;
	If MessageBody.Property("ExternalRef") Then 
		News.ExternalRef	= MessageBody.ExternalRef;
	EndIf;
	If MessageBody.Property("InformationType") Then 
		News.InformationType = InformationCenterServer.GetInformationTypeRef(MessageBody.InformationType);
	Else
		News.InformationType = InformationCenterServer.GetInformationTypeRef("News");
	EndIf;
	
	News.Write();
	
EndProcedure

// Updates news.
//
// Parameters:
// News - CatalogRef.InformationCenterCommonData - ref by news.
// MessageBody - Structure - message body.
//
Procedure UpdateNews(News, MessageBody)
	
	News.InformationType             = InformationCenterServer.GetInformationTypeRef("News");
	News.ID             = MessageBody.ID;
	News.Description              = TrimAll(MessageBody.Description);
	News.Date                      = MessageBody.Date;
	News.ActualityBeginningDate    = MessageBody.ActualityBeginningDate;
	News.ActualityEndingDate = MessageBody.ActualityEndingDate;
	News.Criticality               = MessageBody.Criticality;
	News.DeletionMark           = False;
	If MessageBody.Property("HTMLText") Then 
		News.HTMLText = MessageBody.HTMLText;
	EndIf;
	If MessageBody.Property("Attachments") Then 
		News.Attachments = New ValueStorage(MessageBody.Attachments);
	EndIf;
	If MessageBody.Property("ExternalRef") Then 
		News.ExternalRef	= MessageBody.ExternalRef;
	EndIf;
	News.Write();
	
EndProcedure

// Deletes information center data by ID.
//
// Parameters:
// MessageBody - UUID - unique identifier of news.
//
Procedure DeleteInformationCenterData(ID)
	
	SetPrivilegedMode(True);
	Object = GetDataByID(ID);
	If Object = Undefined Then 
		Return;
	EndIf;
	
	Object.SetDeletionMark(True);
	
EndProcedure

// Return object of Catalog InformationCenterCommonData by identifier.
//
// Parameters:
// ID - UUID - data unique ID.
//
// Returns:
// CatalogObject.InformationCenterCommonData, Undefined.
//
Function GetDataByID(ID)
	
	Query = New Query;
	Query.SetParameter("ID", ID);
	Query.Text =
	"SELECT
	|	InformationCenterCommonData.Ref AS Ref
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	InformationCenterCommonData.ID = &ID";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then 
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Return Selection.Ref.GetObject();
	EndDo;
	
EndFunction

// Returns the unavailability title.
//
// Parameters:
// Title - String - message heading.
// StartDate - Date - unavailability start date.
// EndDate - Date - unavailability end date.
//
// Returns:
// String - title unavailability.
//
Function GenerateInaccessibilityHeader(Title, StartDate, EndDate)
	
	InaccessibilityStartDate	= Format(StartDate, "DF=dd.MM.yyyy HH:mm'");
	DurationUpdate	= DatesDifferenceInMinutes(StartDate, EndDate);
	Pattern = NStr("en='%1 %2 (%3 min)';ru='%1 %2 (%3 мин.)'");
	Pattern = StringFunctionsClientServer.SubstituteParametersInString(Pattern, String(InaccessibilityStartDate), TrimAll(Title), DurationUpdate);
	Return Pattern;
	
EndFunction

// Returns dates difference in minutes.
//
// Parameters:
// StartDate - Date - date of begin.
// EndDate - Date - date of end.
//
// Returns:
// Number - minutes quantity.
//
Function DatesDifferenceInMinutes(StartDate, EndDate)
	
	CountInSeconds = EndDate - StartDate;
	
	Return Round(CountInSeconds / 60);
	
EndFunction