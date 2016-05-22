////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
// Generation of the object number/code for output in the printed forms.
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Deletes infobase prefix and company prefix from the passed row ObjectNumber.
// Variable ObjectNumber must match the pattern: OOYY-XXX...XX or YYXXX...XX, where:
// OO - Company prefix;
// YY - Infobase prefix;
// "-" - separator;
// XXX...XX - object number/code.
// Insignificant prefixes characters (the zero symbol - "0") are deleted also.
//
// Parameters:
//  ObjectNumber - String - object number or code from which it is required to delete prefixes.
//  DeleteCompanyPrefix - Boolean (optional)  - sign of the deletion company prefix;
//                                              by default is False.
//  DeleteInfobasePrefix - Boolean (optional) - flag showing that the infobase prefix is deleted;
//                                              by default is False.
//
// Examples:
//  DeletePrefixesFromObjectNumber("0FGL-000001234", True, True) = "000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", False, True)   = "F-000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", True, False)   = "CH-000001234"
//  DeletePrefixesFromObjectNumber("0FGL-000001234", False, False)     = "FGL-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfobasePrefix = False) Export
	
	If Not NumberContainsStandardPrefix(ObjectNumber) Then
		Return ObjectNumber;
	EndIf;
	
	// Initially empty string of the object number prefix.
	ObjectPrefix = "";
	
	NumberContainsFiveDigitPrefix = NumberContainsFiveDigitPrefix(ObjectNumber);
	
	If NumberContainsFiveDigitPrefix Then
		CompanyPrefix        = Left(ObjectNumber, 2);
		InfobasePrefix = Mid(ObjectNumber, 3, 2);
	Else
		CompanyPrefix = "";
		InfobasePrefix = Left(ObjectNumber, 2);
	EndIf;
	
	CompanyPrefix        = StrReplace(CompanyPrefix, "0", "");
	InfobasePrefix = StrReplace(InfobasePrefix, "0", "");
	
	// Add company prefix.
	If Not DeleteCompanyPrefix Then
		
		ObjectPrefix = ObjectPrefix + CompanyPrefix;
		
	EndIf;
	
	// Add infobase prefix.
	If Not DeleteInfobasePrefix Then
		
		ObjectPrefix = ObjectPrefix + InfobasePrefix;
		
	EndIf;
	
	If Not IsBlankString(ObjectPrefix) Then
		
		ObjectPrefix = ObjectPrefix + "-";
		
	EndIf;
	
	Return ObjectPrefix + Mid(ObjectNumber, ?(NumberContainsFiveDigitPrefix, 6, 4));
EndFunction

// Deletes leading zeros from the object number.
// Variable ObjectNumber must match the pattern: OOYY-XXX...XX or YY-XXX...XX, where
// OO - Company prefix;
// YY - Infobase prefix;
// "-" - separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or code from which the leading zeros are required.
// 
Function DeleteLeadingZerosFromObjectNumber(Val ObjectNumber) Export
	
	UserPrefix = GetUserPrefix(ObjectNumber);
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix = Left(ObjectNumber, 5);
			Number = Mid(ObjectNumber, 6 + StrLen(UserPrefix));
		Else
			Prefix = Left(ObjectNumber, 3);
			Number = Mid(ObjectNumber, 4 + StrLen(UserPrefix));
		EndIf;
		
	Else
		
		Prefix = "";
		Number = Mid(ObjectNumber, 1 + StrLen(UserPrefix));
		
	EndIf;
	
	// Delete leading zeroes on the left in the number.
	Number = StringFunctionsClientServer.DeleteDuplicatedChars(Number, "0");
	
	Return Prefix + UserPrefix + Number;
EndFunction

// Deletes all the user prefixes from the object number (all nonnumeric characters).
// Variable ObjectNumber must match the pattern: OOYY-XXX...XX or YY-XXX...XX, where
// OO - Company prefix;
// YY - Infobase prefix;
// "-" - separator;
// XXX...XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or code from which the leading zeros are required.
// 
Function DeleteUserPrefixesFromObjectNumber(Val ObjectNumber) Export
	
	DigitalCharacterString = "0123456789";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix     = Left(ObjectNumber, 5);
			FullNumber = Mid(ObjectNumber, 6);
		Else
			Prefix     = Left(ObjectNumber, 3);
			FullNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	Else
		
		Prefix     = "";
		FullNumber = ObjectNumber;
		
	EndIf;
	
	Number = "";
	
	For IndexOf = 1 To StrLen(FullNumber) Do
		
		Char = Mid(FullNumber, IndexOf, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			
			Number = Number + Char;
			
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
EndFunction

// Receives user prefix of the object number/code.
// Variable ObjectNumber must match the pattern: OOYY-XXX...XX or YY-XXX...XX, where
// OO - Company prefix;
// YY - Infobase prefix;
// "-" - separator;
// UA - user prefix;
// XX..XX - object number/code.
//
// Parameters:
//  ObjectNumber - String - object number or code from which it is required to get the user prefix.
// 
Function GetUserPrefix(Val ObjectNumber) Export
	
	// Return value of the function (user prefix).
	Result = "";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			ObjectNumber = Mid(ObjectNumber, 6);
		Else
			ObjectNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	EndIf;
	
	DigitalCharacterString = "0123456789";
	
	For IndexOf = 1 To StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, IndexOf, 1);
		
		If Find(DigitalCharacterString, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
EndFunction

// Receives document number for output to print; prefixes and leading zeros are removed from number.
// Function:
// discards company prefix, 
// discards infobase prefix (optional), 
// discards user prefixs (optional),
// removes the leading zeros in the object number.
//
Function GetNumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteCustomPrefix = False) Export
	
	// {Handler: OnReceiveNumberForPrinting} Beginning
	StandardProcessing = True;
	
	ObjectPrefixationClientServerOverridable.OnReceiveNumberToPrint(ObjectNumber, StandardProcessing);
	
	If StandardProcessing = False Then
		Return ObjectNumber;
	EndIf;
	// {Handler: OnReceiveNumberForPrinting} End
	
	// Delete user prefixes from the object number.
	If DeleteCustomPrefix Then
		
		ObjectNumber = DeleteUserPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// Delete leading zeros from the object number.
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// Delete company prefix and infobase prefix from the object number.
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfobasePrefix);
	
	Return ObjectNumber;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function NumberContainsStandardPrefix(Val ObjectNumber)
	
	SeparatorPosition = Find(ObjectNumber, "-");
	
	Return SeparatorPosition = 3
		OR SeparatorPosition = 5
	;
EndFunction

Function NumberContainsFiveDigitPrefix(Val ObjectNumber)
	
	Return Find(ObjectNumber, "-") = 5;
	
EndFunction

#EndRegion
