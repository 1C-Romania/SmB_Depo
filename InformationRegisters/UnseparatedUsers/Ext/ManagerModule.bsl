#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Returns the list of undivided administrators
//
// Returns:
//   ValuesList   - list of the unique IDs with presentations (user names)
//
Function AdministratorList() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	UnseparatedUsers.InfobaseUserID
		|FROM
		|	InformationRegister.UnseparatedUsers AS UnseparatedUsers";
	Selection = Query.Execute().Select();
	AdministratorList = New ValueList;
	While Selection.Next() Do
		IBUser = InfobaseUsers.FindByUUID(
			Selection.InfobaseUserID);
		If IBUser = Undefined Then
			Continue;
		EndIf;		
		HasRoles = False;
		For Each UserRole IN IBUser.Roles Do
			HasRoles = True;
			Break;
		EndDo;
		If Not HasRoles Then
			Continue;
		EndIf;
		If Not Users.InfobaseUserWithFullAccess(IBUser, True) Then
			Continue;
		EndIf;
		AdministratorList.Add(Selection.InfobaseUserID, IBUser.Name);
	EndDo;
	AdministratorList.SortByPresentation();
	Return AdministratorList;
	
EndFunction

// Returns the max order number of the undivided infobase user
//
// Returns:
//  Number
Function MaximalSerialNumber() Export
	
	QueryText = "SELECT
	               |	ISNULL(MAX(UnseparatedUsers.SequenceNumber), 0) AS SequenceNumber
	               |FROM
	               |	InformationRegister.UnseparatedUsers AS UnseparatedUsers";
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.SequenceNumber;
	Else
		Return 0;
	EndIf;
	
EndFunction

// Returns the order number of the undivided infobase user
//
// Parameters:
//  ID - infobase user unique ID
//
// Returns:
//  Number
Function SequenceNumberIBUser(ID) Export
	
	Query = New Query;
	Query.SetParameter("InfobaseUserID", ID);
	Query.Text =
	"SELECT
	|	UnseparatedUsers.SequenceNumber AS SequenceNumber
	|FROM
	|	InformationRegister.UnseparatedUsers AS UnseparatedUsers
	|WHERE
	|	UnseparatedUsers.InfobaseUserID = &InfobaseUserID";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.SequenceNumber;
	Else
		Return "";
	EndIf;
	
EndFunction

#EndIf