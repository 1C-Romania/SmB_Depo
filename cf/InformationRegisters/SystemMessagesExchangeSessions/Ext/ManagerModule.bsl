#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Creates new message exchange session record and returns session ID
//
Function NewSession() Export
	
	Session = New UUID;
	
	RecordStructure = New Structure("Session, StartDate", Session, CurrentUniversalDate());
	
	AddRecord(RecordStructure);
	
	Return Session;
EndFunction

// Receives the session status: Running, Successfully, Error.
//
Function StatusOfSession(Val Session) Export
	
	Result = New Map;
	Result.Insert(0, "Running");
	Result.Insert(1, "Successfully");
	Result.Insert(2, "Error");
	
	QueryText =
	"SELECT
	|	CASE
	|		WHEN SystemMessagesExchangeSessions.EndWithError
	|			THEN 2
	|		WHEN SystemMessagesExchangeSessions.CompletedSuccessfully
	|			THEN 1
	|		ELSE 0
	|	END AS Result
	|FROM
	|	InformationRegister.SystemMessagesExchangeSessions AS SystemMessagesExchangeSessions
	|WHERE
	|	SystemMessagesExchangeSessions.Session = &Session";
	
	Query = New Query;
	Query.SetParameter("Session", Session);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		MessageString = NStr("en='System message exchange session ""%1"" is not found.';ru='Сессия обмена сообщениями системы ""%1"" не найдена.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Session));
		Raise MessageString;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Result[Selection.Result];
EndFunction

// Sets the CompletedSuccessfully flag value to True for a session that is passed to the procedure
//
Procedure FixSuccessfullSessionCompletion(Val Session) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("CompletedSuccessfully", True);
	RecordStructure.Insert("EndWithError", False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Sets the CompletedWithError flag value to True for a session that is passed to the procedure
//
Procedure FixUnsuccessfullSessionCompletion(Val Session) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("CompletedSuccessfully", False);
	RecordStructure.Insert("EndWithError", True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Saves session data and sets the CompletedSuccessfully flag value to True
//
Procedure SaveSessionData(Val Session, Data) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("Data", Data);
	RecordStructure.Insert("CompletedSuccessfully", True);
	RecordStructure.Insert("EndWithError", False);
	UpdateRecord(RecordStructure);
	
EndProcedure

// Reads session data and deletes session record from the infobase
//
Function GetSessionData(Val Session) Export
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.SystemMessagesExchangeSessions");
		LockItem.SetValue("Session", Session);
		Block.Lock();
		
		QueryText =
		"SELECT
		|	SystemMessagesExchangeSessions.Data AS Data
		|FROM
		|	InformationRegister.SystemMessagesExchangeSessions AS SystemMessagesExchangeSessions
		|WHERE
		|	SystemMessagesExchangeSessions.Session = &Session";
		
		Query = New Query;
		Query.SetParameter("Session", Session);
		Query.Text = QueryText;
		
		QueryResult = Query.Execute();
		
		If QueryResult.IsEmpty() Then
			MessageString = NStr("en='System message exchange session ""%1"" is not found.';ru='Сессия обмена сообщениями системы ""%1"" не найдена.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Session));
			Raise MessageString;
		EndIf;
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		Result = Selection.Data;
		
		DeleteRecord(Session);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

// Auxiliary procedures and functions

Procedure AddRecord(RecordStructure)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SystemMessagesExchangeSessions");
	
EndProcedure

Procedure UpdateRecord(RecordStructure)
	
	DataExchangeServer.UpdateRecordToInformationRegister(RecordStructure, "SystemMessagesExchangeSessions");
	
EndProcedure

Procedure DeleteRecord(Val Session)
	
	DataExchangeServer.DeleteRecordSetInInformationRegister(New Structure("Session", Session), "SystemMessagesExchangeSessions");
	
EndProcedure

#EndRegion

#EndIf