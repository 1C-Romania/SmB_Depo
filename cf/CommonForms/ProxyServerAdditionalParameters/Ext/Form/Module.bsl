
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Filling the form data
	Server      = Parameters.Server;
	Port        = Parameters.Port;
	
	HTTPServer  = Parameters.HTTPServer;
	HTTPPort    = Parameters.HTTPPort;
	
	HTTPSServer = Parameters.HTTPSServer;
	HTTPSPort   = Parameters.HTTPSPort;
	
	FTPServer   = Parameters.FTPServer;
	FTPPort     = Parameters.FTPPort;
	
	OneProxyForAllProtocols = Parameters.OneProxyForAllProtocols;
	
	InitFormItems(ThisObject);
	
	For Each ExceptionsListItem IN Parameters.BypassProxyOnAddresses Do
		StrException = ExceptionsAddresses.Add();
		StrException.ServerAddress = ExceptionsListItem.Value;
	EndDo;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure OneProxyForAllProtocolsOnChange(Item)
	
	InitFormItems(ThisObject);
	
EndProcedure

&AtClient
Procedure HTTPServerOnChange(Item)
	
	// If a server is not specified, then set to zero the corresponding port.
	If IsBlankString(ThisObject[Item.Name]) Then
		ThisObject[StrReplace(Item.Name, "Server", "Port")] = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OKButton(Command)
	
	If Not Modified Then
		// If the form data has
		// not been modified, there is no need to return them.
		NotifyChoice(Undefined);
		Return;
	EndIf;
	
	If Not CheckExceptionsServersAddresses() Then
		Return;
	EndIf;
	
	// If checking of the form data is completed
	// successfully, then return additional proxy server settings in the structure.
	ReturnedValuesStructure = New Structure;
	
	ReturnedValuesStructure.Insert("OneProxyForAllProtocols", OneProxyForAllProtocols);
	
	ReturnedValuesStructure.Insert("HTTPServer" , HTTPServer);
	ReturnedValuesStructure.Insert("HTTPPort"   , HTTPPort);
	ReturnedValuesStructure.Insert("HTTPSServer", HTTPSServer);
	ReturnedValuesStructure.Insert("HTTPSPort"  , HTTPSPort);
	ReturnedValuesStructure.Insert("FTPServer"  , FTPServer);
	ReturnedValuesStructure.Insert("FTPPort"    , FTPPort);
	
	ExceptionsList = New ValueList;
	
	For Each AddressStr IN ExceptionsAddresses Do
		If Not IsBlankString(AddressStr.ServerAddress) Then
			ExceptionsList.Add(AddressStr.ServerAddress);
		EndIf;
	EndDo;
	
	ReturnedValuesStructure.Insert("BypassProxyOnAddresses", ExceptionsList);
	
	NotifyChoice(ReturnedValuesStructure);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Executes the initialization of the form
// items, depending on the settings of the proxy server.
//
&AtClientAtServerNoContext
Procedure InitFormItems(Form)
	
	Form.Items.GroupProxyServers.Enabled = Not Form.OneProxyForAllProtocols;
	If Form.OneProxyForAllProtocols Then
		
		Form.HTTPServer  = Form.Server;
		Form.HTTPPort    = Form.Port;
		
		Form.HTTPSServer = Form.Server;
		Form.HTTPSPort   = Form.Port;
		
		Form.FTPServer   = Form.Server;
		Form.FTPPort     = Form.Port;
		
	EndIf;
	
EndProcedure

// Checks the correctness of the servers-exceptions addresses.
// Also informs the user about incorrectly filled addresses.
//
// Return value: Boolean - True if the
// 					  addresses are correct, otherwise False.
//
&AtClient
Function CheckExceptionsServersAddresses()
	
	AddressesAreCorrect = True;
	For Each StrAddress IN ExceptionsAddresses Do
		If Not IsBlankString(StrAddress.ServerAddress) Then
			ProhibitedChars = InadmissibleCharactersInString(StrAddress.ServerAddress,
				"0123456789aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_-.:*?");
			
			If Not IsBlankString(ProhibitedChars) Then
				
				MessageText = StrReplace(NStr("en='Address contains invalid characters: %1';ru='В адресе найдены недопустимые символы: %1'"),
					"%1",
					ProhibitedChars);
				
				IndexString = StrReplace(String(ExceptionsAddresses.IndexOf(StrAddress)), Char(160), "");
				
				CommonUseClientServer.MessageToUser(MessageText,
					,
					"ExceptionsAddresses[" + IndexString + "].ServerAddress");
				AddressesAreCorrect = False;
				
			EndIf;
		EndIf;
	EndDo;
	
	Return AddressesAreCorrect;
	
EndFunction

// Finds and returns invalid characters in the string, separated by commas.
//
// Parameters:
// CheckedString (String) - String, that is being checked
// 							 for existence of invalid characters.
// ValidCharacters (String) - valid characters string.
//
// Return value: String - invalid characters row. Empty string,
// 					  if in the checked string the invalid characters are not detected.
//
&AtClient
Function InadmissibleCharactersInString(CheckedString, AllowedChars)
	
	InadmissibleCharactersList = New ValueList;
	
	StringLength = StrLen(CheckedString);
	For Iterator = 1 To StringLength Do
		CurrentChar = Mid(CheckedString, Iterator, 1);
		If Find(AllowedChars, CurrentChar) = 0 Then
			If InadmissibleCharactersList.FindByValue(CurrentChar) = Undefined Then
				InadmissibleCharactersList.Add(CurrentChar);
			EndIf;
		EndIf;
	EndDo;
	
	InadmissibleCharactersAsString = "";
	Comma                    = False;
	
	For Each ItemInadmissibleCharacter IN InadmissibleCharactersList Do
		
		InadmissibleCharactersAsString = InadmissibleCharactersAsString
			+ ?(Comma, ",", "")
			+ """"
			+ ItemInadmissibleCharacter.Value
			+ """";
		Comma = True;
		
	EndDo;
	
	Return InadmissibleCharactersAsString;
	
EndFunction

#EndRegion
