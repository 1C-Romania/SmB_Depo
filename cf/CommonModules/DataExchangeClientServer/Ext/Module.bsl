////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// For an internal use.
//
Procedure CheckInadmissibleSymbolsInUserNameWSProxy(Val UserName) Export
	
	If StringContainSymbol(UserName, InadmissibleSymbolsInUserNameWSProxy()) Then
		
		MessageString = NStr("en='The %1 user name contains invalid characters.
		|User name must not contain %2 symbols.';ru='В имени пользователя %1 содержатся недопустимые символы.
		|Имя пользователя не должно содержать символы %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
			UserName, InadmissibleSymbolsInUserNameWSProxy());
		Raise MessageString;
	EndIf;
	
EndProcedure

// For an internal use.
//
Function InadmissibleSymbolsInUserNameWSProxy() Export
	
	Return ":";
	
EndFunction

// For an internal use.
//
Function StringContainSymbol(Val String, Val SymbolsString)
	
	For IndexOf = 1 To StrLen(SymbolsString) Do
		
		Char = Mid(SymbolsString, IndexOf, 1);
		
		If Find(String, Char) <> 0 Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

#EndRegion
