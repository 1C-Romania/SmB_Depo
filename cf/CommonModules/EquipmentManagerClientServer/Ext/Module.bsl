
#Region ProgramInterface

// Function fills client workplace description by the user name.
//
Procedure FillWorkplaceDescription(Object, UserName) Export
	
	NameEmptyUser = NStr("en='<User>';ru='<Пользователь>'");
	
	If IsBlankString(Object.Description) Then
		
		If IsBlankString(UserName) Then
			Object.Description = "<" + NameEmptyUser + ">";
		Else
			Object.Description = String(UserName);
		EndIf;
		
		If IsBlankString(Object.ComputerName) Then
			Object.Description = Object.Description + "(" + Object.Code           + ")";
		Else
			Object.Description = Object.Description + "(" + Object.ComputerName + ")";
		EndIf;
		
	ElsIf Not IsBlankString(String(UserName))
	          AND Find(Object.Description, NameEmptyUser) > 0 Then
	
		Object.Description = StrReplace(Object.Description, NameEmptyUser, String(UserName));
	
	EndIf;

EndProcedure

#EndRegion