#Region ServiceProceduresAndFunctions

&AtClient
// Determines whether the card code
// matches the Output template:
// TracksData - Array containing rows of the track code. 3 items totally.
// PatternData - a structure containing template data:
// - Suffix
// - Prefix
// - BlocksDelimiter
// - CodeLength
// Output:
// True - code matches template
Function CodeCorrespondsToMCTemplate()
	
	// Check only Track 2.
	curRow = CardCode;
	If Right(curRow, StrLen(Object.Suffix)) <> Object.Suffix
		OR Left(curRow, StrLen(Object.Prefix)) <> Object.Prefix
		OR Find(curRow, Object.BlocksDelimiter) = 0
		OR (Object.CodeLength <> 0 AND StrLen(curRow) <> Object.CodeLength) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName ="TracksData" Then
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			CurDate = CurrentDate();
			
			CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode");
			CardCode = Parameter[1][1][1]; // Card code from 2nd lane.
			
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			// You can cut the newline character in the peripherals settings to read magnetic cards.
			While (CurrentDate() - CurDate) < 1 Do EndDo;
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "MagneticCardReader");
	// End Peripherals
	
EndProcedure

&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - handler of the CheckCodeByTemplate form command.
//
&AtClient
Procedure CheckTemplate(Command)
	
	If Not ValueIsFilled(CardCode) Then
		SmallBusinessClient.ShowMessageAboutError(ThisForm, "Card code (as an example) is not filled",,,"CardCode");
		Return;
	EndIf;
	
	If Object.CodeLength > 0 Then
		CodeLengthAsExample = StrLen(CardCode);
		If CodeLengthAsExample <> Object.CodeLength Then
			SmallBusinessClient.ShowMessageAboutError(ThisForm, "Invalid code length. Code length as an example = "+CodeLengthAsExample+".",,,"Object.CodeLength");
			Return;
		EndIf;
	EndIf;
	
	TemplatesList = New Array;
		
	If Not CodeCorrespondsToMCTemplate() Then
		SmallBusinessClient.ShowMessageAboutError(ThisObject, "Invalid prefix, suffix or blocks delimiter");
		Return;
	EndIf;
	
	TrackData = New Array;
	
	// Search block by number
	DataRow = CardCode; // Process data only from the Track 2.
	Prefix = Object.Prefix;
	If Prefix = Left(DataRow, StrLen(Prefix)) Then
		DataRow = Right(DataRow, StrLen(DataRow)-StrLen(Prefix)); // Remove prefix if any
	EndIf;
	Suffix = Object.Suffix;
	If Suffix = Right(DataRow, StrLen(Suffix)) Then
		DataRow = Left(DataRow, StrLen(DataRow)-StrLen(Suffix)); // Remove suffix if any
	EndIf;
	
	BlocksDelimiter = Object.BlocksDelimiter;
	curBlockNumber = 0;
	While curBlockNumber < ?(Object.BlockNumber = 0, 1, Object.BlockNumber) Do
		SeparatorPosition = Find(DataRow, BlocksDelimiter);
		If IsBlankString(BlocksDelimiter) OR SeparatorPosition = 0 Then
			Block = DataRow;
		ElsIf SeparatorPosition = 1 Then
			Block = "";
			DataRow = Right(DataRow, StrLen(DataRow)-1);
		Else
			Block = Left(DataRow, SeparatorPosition-1);
			DataRow = Right(DataRow, StrLen(DataRow)-SeparatorPosition);
		EndIf;
		curBlockNumber = curBlockNumber + 1;
	EndDo;
	
	// Search substring in the block
	FieldValue = Mid(Block, Object.FirstFieldSymbolNumber, ?(Object.FieldLenght = 0, StrLen(Block), Object.FieldLenght));
	
	CardCodeByTemplate = FieldValue;
		
EndProcedure

#EndRegion

 