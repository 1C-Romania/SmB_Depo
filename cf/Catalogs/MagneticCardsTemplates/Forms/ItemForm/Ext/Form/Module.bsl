
#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		Object.BlocksDelimiter1 = "^";
		Object.BlocksDelimiter2 = "=";
		Object.BlocksDelimiter3 = "=";
		
		Object.CodeLength1 = 79;
		Object.CodeLength2 = 40;
		Object.CodeLength3 = 107;
		
		Object.Prefix1 = "%";
		Object.Prefix2 = ";";
		Object.Prefix3 = ";";
		
		Object.Suffix1 = "?";
		Object.Suffix2 = "?";
		Object.Suffix3 = "?";
		
		Object.TrackAvailability1 = True;
		Object.TrackAvailability2 = True;
		Object.TrackAvailability3 = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, SupporTypesVO, ErrorDescription) Then
			MessageText = NStr("en='An error occurred while
		|connecting peripherals: ""%ErrorDetails%"".';ru='При подключении оборудования
		|произошла ошибка: ""%ОписаниеОшибки%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	// End Peripherals
	
	SetTracksEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				TracksData = Parameter[0];
			Else
				TracksData = Parameter[1][1];
			EndIf;
			
			// Display data that was read
			Track1 = TracksData[0];
			Track2 = TracksData[1];
			Track3 = TracksData[2];
			Object.CodeLength1 = StrLen(Track1);
			Object.CodeLength2 = StrLen(Track2);
			Object.CodeLength3 = StrLen(Track3);
			Object.TrackAvailability1 = Not (StrLen(Track1) = 0);
			Object.TrackAvailability2 = Not (StrLen(Track2) = 0);
			Object.TrackAvailability3 = Not (StrLen(Track3) = 0);
			SetTracksEnabled();
			
			Modified = True;
			
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure OnClose()
	// Peripherals
	SupporTypesVO = New Array();
	SupporTypesVO.Add("MagneticCardReader");

	EquipmentManagerClient.DisableEquipmentByType(UUID, SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// Checking on field existence
	ClearMessages();
	FieldCounter = 0;
	If Object.TrackAvailability1 Then
		FieldCounter = FieldCounter + Object.TrackFields1.Count();
	EndIf;
	If Object.TrackAvailability2 Then
		FieldCounter = FieldCounter + Object.TrackFields2.Count();
	EndIf;
	If Object.TrackAvailability3 Then
		FieldCounter = FieldCounter + Object.TrackFields3.Count();
	EndIf;
	If FieldCounter = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en='Not a single field was added to any of available tracks.';ru='Не добавлено ни одного поля ни в одной из доступных дорожек.'"), , , , Cancel);
	EndIf;
	
	ControlOfFieldsUniqueness(Cancel);
	
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en='An error occurred during the processing of external event from the device:';ru='При обработке внешнего события от устройства произошла ошибка:'")
								+ Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GetPrefix1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.Prefix1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetPrefix2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.Prefix2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetPrefix3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.Prefix3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.Suffix1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.Suffix2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.Suffix3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.BlocksDelimiter1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.BlocksDelimiter2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.BlocksDelimiter3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetField1End(Result, Parameters) Export
	
	Items.TrackFields1.AddRow();
	NewField = Items.TrackFields1.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields1.EndEditRow(False);
	
EndProcedure  

&AtClient
Procedure GetField1(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
		
	If StrLen(Items.Track1.SelectedText) = 0 Then
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField1End", ThisObject, );

	Items.Track1.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track1, Object.Prefix1, Object.Suffix1, Object.BlocksDelimiter1, NCol, CCol);
	
EndProcedure

&AtClient
Procedure GetField2End(Result, Parameters) Export
	
	Items.TrackFields2.AddRow();
	NewField = Items.TrackFields2.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields2.EndEditRow(False);
	
EndProcedure  

&AtClient
Procedure GetField2(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
	
	If StrLen(Items.Track2.SelectedText) = 0 Then
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField2End", ThisObject, Parameters);

	Items.Track2.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track2, Object.Prefix2, Object.Suffix2, Object.BlocksDelimiter2, NCol, CCol);
	
EndProcedure

&AtClient
Procedure GetField3End(Result, Parameters) Export
	
	Items.TrackFields3.AddRow();
	NewField = Items.TrackFields3.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields3.EndEditRow(False);
	
EndProcedure  

&AtClient
Procedure GetField3(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
	
	If StrLen(Items.Track3.SelectedText) = 0 Then
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Use mouse to select the part of the code.';ru='Выделите мышкой участок кода.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField3End", ThisObject, );

	Items.Track3.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track3, Object.Prefix3, Object.Suffix3, Object.BlocksDelimiter3, NCol, CCol);
	//
EndProcedure

&AtClient
Procedure DetermineFieldCoordinatesEnd(Result, Context) Export
	
	If Result.Value = DialogReturnCode.No Then
		Context.Result.FieldLenght = 0;
	EndIf;
	
	If Context <> Undefined AND Context.NextAlert <> Undefined Then
		ExecuteNotifyProcessing(Context.NextAlert, Context.Result);
	EndIf;
	
EndProcedure
   
// Specifies the field coordinates by selected section of the path code.
//
&AtClient
Procedure DetermineFieldCoordinates(Notification, TrackData, Prefix, Suffix, Delimiter, NCol, CCol)
	
	DataRow = TrackData;
	If Not IsBlankString(Prefix)
		AND Prefix = Left(DataRow, StrLen(Prefix)) Then
		DataRow = Right(DataRow, StrLen(DataRow)-StrLen(Prefix)); // cut prefix if any
		NCol = NCol - StrLen(Prefix);
		CCol = CCol - StrLen(Prefix);
		If NCol < 1 Then
			// Selected text overlaps the prefix.
			CommonUseClientServer.MessageToUser(NStr("en='Selected part of the code should not overlap the suffix, prefix or block delimiter.';ru='Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.'"));
			Return;
		EndIf;
	EndIf;
	
	If Not IsBlankString(Suffix)
		AND Suffix = Right(DataRow, StrLen(Suffix)) Then
		DataRow = Left(DataRow, StrLen(DataRow)-StrLen(Suffix)); // cut suffix if any
		If CCol-1 > StrLen(DataRow) Then
			// Selected text overlaps the suffix.
			CommonUseClientServer.MessageToUser(NStr("en='Selected part of the code should not overlap the suffix, prefix or block delimiter.';ru='Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.'"));
			Return;
		EndIf;
	EndIf;
	
	SeparatorIsFound = Find(Mid(DataRow, NCol, CCol-NCol), Delimiter);
	If Not IsBlankString(Delimiter) AND SeparatorIsFound > 0 Then
		// Selected text crosses the delimiter.
		CommonUseClientServer.MessageToUser(NStr("en='Selected part of the code should not overlap the suffix, prefix or block delimiter.';ru='Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.'"));
		Return;
	EndIf;
	
	BlockNumber = 1;
	FirstFieldSymbolNumber = 1;
	FieldLenght = 1;
	
	While StrLen(DataRow) > 0 Do
		SeparatorPosition = Find(DataRow, Delimiter);
		If SeparatorPosition > NCol Then
			FirstFieldSymbolNumber = NCol;
			FieldLenght = ?(CCol > SeparatorPosition, SeparatorPosition - NCol, CCol - NCol);
			Break;
		EndIf;
		
		If SeparatorPosition = 0 OR IsBlankString(Delimiter) Then
			FirstFieldSymbolNumber = NCol;
			FieldLenght = CCol - NCol;
			Break;
		ElsIf SeparatorPosition = 1 Then
			// Selected text crosses the delimiter.
			CommonUseClientServer.MessageToUser(NStr("en='Selected part of the code should not overlap the suffix, prefix or block delimiter.';ru='Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.'"));
			Return;
		Else
			DataRow = Right(DataRow, StrLen(DataRow)-SeparatorPosition);
			NCol = NCol - SeparatorPosition;
			CCol = CCol - SeparatorPosition;
		EndIf;
		BlockNumber = BlockNumber + 1;
	EndDo;
	
	If CCol = StrLen(DataRow)+1
		OR Mid(DataRow, CCol, 1) = Delimiter Then
		
		Result = New Structure("BlockNumber, FirstFieldSymbolNumber, FieldLenght", BlockNumber, FirstFieldSymbolNumber, FieldLenght);
		
		Context = New Structure;
		Context.Insert("NextAlert", Notification);
		Context.Insert("Result", Result);
		NextAlert = New NotifyDescription("DetermineFieldCoordinatesEnd", ThisObject, Context);
		
		ButtonList = New ValueList;
		ButtonList.Add(DialogReturnCode.Yes, NStr("en='Field length is fixed';ru='Длина поля фиксированная'"));
		ButtonList.Add(DialogReturnCode.No, NStr("en='Field length is limited by the delimiter or by the string end';ru='Длина поля ограничивается разделителем или концом строки'"));
		ShowChooseFromMenu(NextAlert, ButtonList, );
		Return;
		//	
		//Response = DoQueryBox(NStr("en='Length of selected field is fixed or limited by delimiter/string end?
		// |""Yes"" - field length fixed
		// |""No""  - length fields limited by delimiter or string end'"), QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en='Length fields in characters';ru='Длина поля в символах'"));
		//	
		//If Response = DialogReturnCode.Not Then
		//	
		//	FieldLength = 0;
		//	
		//EndIf;
		
	EndIf;
	
	Result = New Structure("BlockNumber, FirstFieldSymbolNumber, FieldLenght", BlockNumber, FirstFieldSymbolNumber, FieldLenght);
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

&AtClient
Procedure ControlOfFieldsUniqueness(Cancel)
	
	DoublesList = New Array;
	For y = 1 To 3 Do
		If Object["TrackAvailability"+String(y)] Then
			For Each curRow IN Object["TrackFields"+String(y)] Do
				ControlOfFieldUniqueness(DoublesList, curRow.Field, curRow.LineNumber, "TrackFields"+String(y), Cancel);
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ControlOfFieldUniqueness(DoublesList, Field, CurrentLineNumber, TableName, Cancel)
	If ValueIsFilled(Field) Then
		If DoublesList.Find(Field) = Undefined Then
			TwinCounter = 0;
			For G = 1 To 3 Do
				If Not Object["TrackAvailability"+String(G)] Then
					Continue;
				EndIf;
				
				For Each curField IN Object["TrackFields"+String(G)] Do
					If curField.Field = Field Then
						TwinCounter = TwinCounter + 1;
						If TwinCounter > 1 Then
							StrMessage = NStr("en='Track %1, string %2: Field should be unique!';ru='Дорожка %1, строка %2: Поле должно быть уникальным!'");
							StrMessage = StrReplace(StrMessage, "%1", Right("TrackFields"+String(G),1));
							StrMessage = StrReplace(StrMessage, "%2", String(curField.LineNumber));
							CommonUseClientServer.MessageToUser(StrMessage
								, ,"Object."+"TrackFields"+String(G)+"["+String(curField.LineNumber-1)+"].Field", , Cancel);
						EndIf;
					EndIf;
				EndDo;
			EndDo;
			If TwinCounter > 1 Then
				DoublesList.Add(Field);
			EndIf;
		EndIf;
		
	Else
		StrMessage = NStr("en='Field can not be empty!';ru='Дорожка %1, строка %2: Поле не может быть пустым!'");
		StrMessage = StrReplace(StrMessage, "%1", Right(TableName,1));
		StrMessage = StrReplace(StrMessage, "%2", String(CurrentLineNumber));
		CommonUseClientServer.MessageToUser(StrMessage
			, ,"Object."+TableName+"["+String(CurrentLineNumber-1)+"].Field", , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckTemplate()
	
	PatternData = New Structure(
		"TrackAvailability1, TrackAvailability2, TrackAvailability3, "
		+ "Prefix1, Prefix2, Prefix3, "
		+ "CodeLength1, CodeLength2, CodeLength3, "
		+ "Suffix1, Suffix2, Suffix3, "
		+ "BlocksDelimiter1, BlocksDelimiter2, BlocksDelimiter3, "
		+ "Ref",
		Object.TrackAvailability1, Object.TrackAvailability2, Object.TrackAvailability3
		,Object.Prefix1, Object.Prefix2, Object.Prefix3
		,Object.CodeLength1, Object.CodeLength2, Object.CodeLength3
		,Object.Suffix1, Object.Suffix2, Object.Suffix3
		,Object.BlocksDelimiter1, Object.BlocksDelimiter2, Object.BlocksDelimiter3
		,Object.Ref);
		
	OpenForm("Catalog.MagneticCardsTemplates.Form.TemplateCheckForm"
		, New Structure("PatternData", PatternData), ThisForm, ,,,, FormWindowOpeningMode.LockWholeInterface);      
	
EndProcedure

&AtClient
Procedure CheckTemplateEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If Not ThisForm.Write() Then
			CommonUseClientServer.MessageToUser(NStr("en='Failed to record template';ru='Не удалось записать шаблон'"));
			Return;
		EndIf;
		
		CheckTemplate();
		
	EndIf;  
	
EndProcedure  

&AtClient
Procedure CheckTemplateCommand(Command)
	
	// Check form on modification.
	// IN order the changes in template come into effect, you must save them.
	If ThisForm.Modified Then
		QuestionText = NStr("en='Template was changed, record changes?';ru='Шаблон был изменен, записать изменения?'");
		Notification = New NotifyDescription("CheckTemplateEnd", ThisObject);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	Else
		CheckTemplate();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Sets the path field availability depending on the position of corresponding flag.
&AtClient
Procedure TrackAvailability1OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure TrackAvailability2OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure TrackAvailability3OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure SetTracksEnabled()
	For y = 1 To 3 Do
		TrackAvailability = Object["TrackAvailability"+String(y)];
		Items["Prefix"+String(y)].Enabled 			= TrackAvailability;
		Items["CodeLength"+String(y)].Enabled 		= TrackAvailability;
		Items["Suffix"+String(y)].Enabled 			= TrackAvailability;
		Items["BlocksDelimiter"+String(y)].Enabled = TrackAvailability;
		Items["TrackFields"+String(y)].Enabled 		= TrackAvailability;
	EndDo;
EndProcedure

#EndRegion
