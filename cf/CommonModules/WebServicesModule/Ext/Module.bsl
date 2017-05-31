Function IsObjectLockedForWebService(Object,User = Undefined,LockUser = Undefined) Export
	
	If User=Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;	
	
	Query = New Query();
	Query.Text = "SELECT TOP 1
	             |	WebServiceLocks.Object,
	             |	WebServiceLocks.User,
	             |	WebServiceLocks.LockTime
	             |FROM
	             |	InformationRegister.WebServiceLocks AS WebServiceLocks
	             |WHERE
	             |	WebServiceLocks.Object = &Object
	             |	AND WebServiceLocks.User <> &User";
	Query.SetParameter("Object",Object);
	Query.SetParameter("User",User);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		LockUser = Selection.User;
		Return True;
		
	EndIf;	
	
EndFunction	

Function IsObjectLockedByUser(Object,User = Undefined) Export
	
	If User=Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;	
	
	Query = New Query();
	Query.Text = "SELECT TOP 1
	             |	WebServiceLocks.Object,
	             |	WebServiceLocks.User,
	             |	WebServiceLocks.LockTime
	             |FROM
	             |	InformationRegister.WebServiceLocks AS WebServiceLocks
	             |WHERE
	             |	WebServiceLocks.Object = &Object
	             |	AND WebServiceLocks.User = &User";
	Query.SetParameter("Object",Object);
	Query.SetParameter("User",User);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;	
	
EndFunction	

Function GetUserLocks(User = Undefined) Export
	
	If User=Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;	
	
	Query = New Query();
	Query.Text = "SELECT
	             |	WebServiceLocks.Object AS Object
	             |FROM
	             |	InformationRegister.WebServiceLocks AS WebServiceLocks
	             |WHERE
	             |	WebServiceLocks.User = &User";
	Query.SetParameter("User",User);
	QueryResult = Query.Execute();
	Return QueryResult.Unload().UnloadColumn("Object");
	
EndFunction	

Procedure WebServiceLocksChecker() Export
	
	ServerDate = GetServerDate();
	Timeout = 1*60*60; // 12 hours
	Timeout2 = 1*60*60; // 3 hours
	
	Query = New Query;
	Query.Text = "SELECT
	             |	WebServiceLocks.Object
	             |FROM
	             |	InformationRegister.WebServiceLocks AS WebServiceLocks
	             |WHERE
	             |	(DATEDIFF(&ServerDate, WebServiceLocks.LockTime, SECOND) >= &Timeout
	             |			OR DATEDIFF(&ServerDate, WebServiceLocks.LastUseTime, SECOND) >= &Timeout2)";
	Query.SetParameter("ServerDate",ServerDate);
	Query.SetParameter("Timeout",Timeout);
	Query.SetParameter("Timeout2",Timeout2);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Privileged.UnLockObjectForWebService(Selection.Object,False);
	EndDo;	
	
EndProcedure
