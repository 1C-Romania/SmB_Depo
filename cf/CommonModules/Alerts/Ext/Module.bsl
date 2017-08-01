//////////////////////// EXPORT FUNCTIONS

Function AlertObjectAttributesValidation(Object, AttributesValueTable, Cancel = Undefined,Form = Undefined) Export
	
	ObjectMetadata = Object.Metadata();

	MetadataAttributes = ObjectMetadata.Attributes;
	
	For Each Row In AttributesValueTable Do
				
		// perform checking
		If Row.Type = Enums.AlertsAttributesPropertyType.Attribute Then
			
			If ValueIsNotFilled(Object[Row.Name]) Then
				
				AttributePresentation = Row.Presentation;
				
				MetadataAttributesObject = MetadataAttributes.Find(Row.Name);
				
				If IsBlankString(AttributePresentation) 
					AND MetadataAttributesObject<> Undefined Then
					
					AttributePresentation = MetadataAttributesObject.Presentation();
					
				EndIf;

				ErrorText = CommonAtClientAtServer.ParametrizeString(NStr("en = 'Please, input attribute''s value: ""%P1""!'; pl = 'Wprowadź wartość atrybutu: ""%P1""!'"),New Structure("P1",TrimAll(AttributePresentation)));
				WarningText = CommonAtClientAtServer.ParametrizeString(NStr("en = 'Please, check attribute''s value: ""%P1""! Maybe, it should be filled?'; pl = 'Sprawdź wartość atrybutu: ""%P1""! Czy on naprawde powinnien być pusty?'"),New Structure("P1",TrimAll(AttributePresentation)));
				AlertText = ?(Row.Status = Enums.AlertType.Error,ErrorText,WarningText);
				If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
					AddAlert(?(Row.AlertMessage = "",Row.BeginMessage + AlertText,Row.BeginMessage + Row.AlertMessage),Row.Status,Cancel,Object,Form);
				Else
					Form = "Object." + Row.Name;
					AddAlert(?(Row.AlertMessage = "",Row.BeginMessage + AlertText,Row.BeginMessage + Row.AlertMessage),Row.Status,Cancel,Object,Form);
				EndIf;
			EndIf;	
			
		EndIf;
		
	EndDo;
	
EndFunction

Function AlertObjectTabularPartsAttributesValidation(Object, TabularPartsStructure, Cancel = Undefined) Export
	
	If TabularPartsStructure <> Undefined Then
		For Each KeyAndValue In TabularPartsStructure Do
			
			TabularSectionName = KeyAndValue.Key;
			TabularPartValueTable = KeyAndValue.Value;
			
			If ValueIsFilled(TabularSectionName) Then
				AlertObjectTabularPartAttributesValueTableValidation(Object,TabularSectionName,TabularPartValueTable,Cancel);
			EndIf;	
			
		EndDo;
	EndIf;
	
EndFunction	

Procedure AlertDoCommonCheck(Object,AllAttributesValueTable = Undefined,AllTabularPartsAttributesStructure = Undefined, Cancel = Undefined) Export
	
	If Object = Undefined Then 
		Return;
	EndIf;
	
	If AllAttributesValueTable <> Undefined Then
		Alerts.AlertObjectAttributesValidation(Object,AllAttributesValueTable,Cancel);
	EndIf;
	
	If AllTabularPartsAttributesStructure <> Undefined Then
		Alerts.AlertObjectTabularPartsAttributesValidation(Object,AllTabularPartsAttributesStructure,Cancel);
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Object.Ref))
		OR Tasks.AllRefsType().ContainsType(TypeOf(Object.Ref))
		OR BusinessProcesses.AllRefsType().ContainsType(TypeOf(Object.Ref)) Then
		Try
			Object.DocumentChecks(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.DocumentChecks(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;	
		EndTry;
		
		Try
			Object.DocumentChecksTabularPart(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.DocumentChecksTabularPart(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;	
		EndTry;
		
	Else
		Try
			Object.ElementChecks(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.ElementChecks(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;
		EndTry;
	EndIf;	
	
EndProcedure

///// Complicate conditions

/// Working with VT

Function AddAttributesValueTableRow(AttributesValueTable, Name, Presentation = "", Type, Status, AlertMessage = "", BeginMessage = "") Export

	NewRow = AttributesValueTable.Add();
	NewRow.Name = Name;
	NewRow.Presentation = Presentation;
	NewRow.Type = Type;
	NewRow.Status = Status;
	NewRow.AlertMessage = AlertMessage;
	NewRow.BeginMessage = BeginMessage;
	
	Return AttributesValueTable;
	
EndFunction	

Function AddAttributesValueTableRowFromRow(AttributesValueTable, AnotherValueTableRow) Export
	
	NewRow = AttributesValueTable.Add();
	NewRow.Name = AnotherValueTableRow.Name;
	NewRow.Presentation = AnotherValueTableRow.Presentation;
	NewRow.Type = AnotherValueTableRow.Type;
	NewRow.Status = AnotherValueTableRow.Status;
	NewRow.AlertMessage = AnotherValueTableRow.AlertMessage;
	NewRow.BeginMessage = AnotherValueTableRow.BeginMessage;
	
	Return AttributesValueTable;
	
EndFunction	

Function AddTabularPartsAttributesStructureRow(TabularPartsStructure,TabularPartName, Name, Presentation = "", Type, Status, AlertMessage = "") Export
	
	If TabularPartsStructure = Undefined Then
		TabularPartsStructure = New Structure();
	EndIf;
	
	TabularPartValueTable = Undefined;
	TabularPartsStructure.Property(TabularPartName,TabularPartValueTable);
	
	If TabularPartValueTable = Undefined Then
		TabularPartValueTable = CreateAttributesValueTable();
	EndIf;
	
	TabularPartValueTable = AddAttributesValueTableRow(TabularPartValueTable,Name,Presentation,Type,Status,AlertMessage);
	
	If TabularPartsStructure.Property(TabularPartName) Then
		TabularPartsStructure[TabularPartName] = TabularPartValueTable;
	Else
		TabularPartsStructure.Insert(TabularPartName,TabularPartValueTable);
	EndIf;	
	
	Return TabularPartsStructure;
	
EndFunction	

Function AlertsExpandAttributesValueTable(SourceAttributesValueTable, AppendingAttributesValueTable) Export
	
	If AppendingAttributesValueTable = Undefined OR AppendingAttributesValueTable.Count()<=0 Then
		
		// return AlertsTable without changing anything (create a new table if undefined)
		Return ?(SourceAttributesValueTable = Undefined, CreateAttributesValueTable(), SourceAttributesValueTable);
		
	Else	
		
		If TypeOf(AppendingAttributesValueTable) = Type("Structure") Then
			
			AppendingAttributesValueTable = AlertCreateAttributesValueTableFromStructure(AppendingAttributesValueTable,Enums.AlertType.Error);
			
		EndIf;	
		
	EndIf;	
	
	If SourceAttributesValueTable = Undefined Then
		
		SourceAttributesValueTable = CreateAttributesValueTable();
		
	Else
		
		If TypeOf(SourceAttributesValueTable) = Type("Structure") Then
			
			SourceAttributesValueTable = AlertCreateAttributesValueTableFromStructure(SourceAttributesValueTable,Enums.AlertType.Error);
			
		EndIf;	
		
	EndIf;	
	
	For Each Row In AppendingAttributesValueTable Do
		
		FoundRow = SourceAttributesValueTable.Find(Row.Name,"Name");
		
		If FoundRow <> Undefined Then
			
			If FoundRow.Status <> Row.Status Then // Differs
				
				FoundRow.Status = Enums.AlertType.Error;
				
			EndIf;	
			
		Else // not found
			
			AddAttributesValueTableRowFromRow(SourceAttributesValueTable,Row);
			
		EndIf;
		
	EndDo;
	
	Return SourceAttributesValueTable;
	
EndFunction	

Function AlertsExpandTabularPartsAttributesStructure(SourceAttributesStructure, AppendingAttributesStructure) Export
	
	If AppendingAttributesStructure=Undefined OR AppendingAttributesStructure.Count()<=0 Then
		
		Return SourceAttributesStructure;
		
	EndIf;	
	
	If SourceAttributesStructure = Undefined Then
		
		SourceAttributesStructure = New Structure();
		
	EndIf;	

	
	For Each KeyAndValue In AppendingAttributesStructure Do
		
		SourceAttributesValueTable = Undefined;
		// Searching appending key in source structure
		If SourceAttributesStructure.Property(KeyAndValue.Key,SourceAttributesValueTable) Then
			
			NewSourceAttributesValueTable = AlertsExpandAttributesValueTable(SourceAttributesValueTable,KeyAndValue.Value);
			SourceAttributesStructure.Delete(KeyAndValue.Key);
			SourceAttributesStructure.Insert(KeyAndValue.Key,NewSourceAttributesValueTable);
			
		Else // not found
			
			SourceAttributesStructure.Insert(KeyAndValue.Key,KeyAndValue.Value);
			
		EndIf;
		
	EndDo;
	
	Return SourceAttributesStructure;
	
EndFunction	

///// Working with structures
Function AlertCreateAttributesValueTableFromStructure(SourceStructure, NewStatus = Undefined,NewAlertMessage = "",NewBeginMessage = "") Export
	
	NewValueTable = CreateAttributesValueTable();
	
	If SourceStructure <> Undefined Then
		
		For Each KeyAndValue In SourceStructure Do
			
			NewRow = NewValueTable.Add();
			NewRow.Name = KeyAndValue.Key;
			NewRow.Presentation = KeyAndValue.Value;
			NewRow.Type = Enums.AlertsAttributesPropertyType.Attribute;
			NewRow.Status = NewStatus;
			NewRow.AlertMessage = NewAlertMessage;
			NewRow.BeginMessage = NewBeginMessage;
			
		EndDo;
		
	EndIf;
	
	Return NewValueTable;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// Filling and printing alerts table

Function ClearAlertsTable(Object = Undefined,Form = Undefined) Export
	
	If Object <> Undefined Then
		If Form = Undefined Then
			Try
				AdditionalProperties = Object.AdditionalProperties;
			Except
				AdditionalProperties = New Structure();
			EndTry; 
			AdditionalProperties.Property("EditingInForm",Form);
		EndIf;
	EndIf;		
	
EndFunction	

Procedure AddAlert(AlertText,AlertStatus = Undefined,Cancel = Undefined, Object = Undefined, Val Form = Undefined,NotificationEvent = Undefined) Export
	
	If AlertStatus = Undefined Then
		AlertStatus = Enums.AlertType.Error;
	EndIf;	
	
	AlertTextWithDocumentPresentation = AlertText;
	If Object <> Undefined Then
		
		Try	
			
			AdditionalProperties = Object.AdditionalProperties;
			
		Except
			
			AdditionalProperties = New Structure();
			
		EndTry; 
		
		// should be there because of notifications...
		DocumentPresentation = "";
		If AdditionalProperties.Property("DocumentPresentation", DocumentPresentation) Then
			AlertTextWithDocumentPresentation = DocumentPresentation + AlertText;
		EndIf;
	EndIf;	
	
	If ValueIsFilled(NotificationEvent) Then
		
		If TypeOf(NotificationEvent) = Type("Array") Then
			For Each ArrayItem In NotificationEvent Do
				Notifications.AddNotification(AlertTextWithDocumentPresentation,ArrayItem);
			EndDo;	
		Else	
			Notifications.AddNotification(AlertTextWithDocumentPresentation,NotificationEvent);
		EndIf;	
		
	EndIf;	
	
	If Object <> Undefined Then
		
		If AlertStatus = Enums.AlertType.Warning Then
			
			//If IsInRole("Right_General_YellowAlertDontBlockPosting") Then
			//	
			//	If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
			//		#If Client Then
					AlertMessage(AlertTextWithDocumentPresentation,AlertStatus,Cancel);
					//#EndIf
				
					Return;
			//	EndIf;
			//EndIf;
			
			
			If AdditionalProperties.Property("OmitWarnings") Then
				
				Return;
				
			EndIf;	
			
		EndIf;	
		
		Form = GetAdditionalPropertiesForm(Object,Form);
		
		If Form <> Undefined Then
			If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
			#If Client Then
				// There is no object
				AlertsForm = SetAlertsFormObject(Object,Form);
				AlertsForm.AddAlert(AlertText,AlertStatus);
				If NOT AlertsForm.IsOpen() Then
					AlertsForm.Open();
				EndIf;	
				
				Cancel = True;

			#EndIf
			Else
				CommonAtClientAtServer.NotifyUser(AlertTextWithDocumentPresentation, , Form);
				Cancel = True;
			EndIf;
		Else
			
			AlertMessage(AlertTextWithDocumentPresentation,AlertStatus,Cancel,Object.Metadata(),Object);
			
			If AlertStatus = Enums.AlertType.Error Then
				Cancel = True;
			EndIf;
			
		EndIf;
		
		AdditionalTarger = "";
		Try
			AdditionalTarger = Object.AdditionalProperties.FormOwnerUUID;
		Except
		EndTry;

		If Not AdditionalTarger = "" Then
			CommonAtClientAtServer.NotifyUser(AlertTextWithDocumentPresentation, Object,,,Cancel, AlertStatus, AdditionalTarger);
		EndIf;
	Else
		
		AlertMessage(AlertTextWithDocumentPresentation,AlertStatus,Cancel);
		
	EndIf;	
		
EndProcedure

Function GetAdditionalPropertiesForm(Object,Form = Undefined) Export
	
	If Form = Undefined Then
		
		Try
			
			AdditionalProperties = Object.AdditionalProperties;
			
		Except
			
			AdditionalProperties = New Structure();
			
		EndTry; 
		
		AdditionalProperties.Property("EditingInForm",Form);
		
	EndIf;
	
	Return Form;
	
EndFunction	

Function SetAlertsFormObject(Object, Form) Export
	AlertsForm = GetCommonForm("AlertsForm",Form,Form);
	AlertsForm.Object = Object;
	Return AlertsForm;
EndFunction	

Function AlertMessage(AlertText,AlertStatus = Undefined,Cancel = Undefined, ObjectMetadata = Undefined,Object = Undefined) Export
	
	If AlertStatus = Undefined 
		OR AlertStatus = Enums.AlertType.Error Then
		Status = MessageStatus.Important;
		Cancel = True;
	ElsIf AlertStatus = Enums.AlertType.Warning Then
		Status = MessageStatus.Information;
	EndIf;
	
	#If ExternalConnection Then
		
		If AlertStatus = Undefined 
			OR AlertStatus = Enums.AlertType.Error Then
			Raise(AlertText);
		Else
			WriteAlertAsLogEvent(AlertText,Status, Object,ObjectMetadata);
		EndIf;	
		
	#Else
		
		#If Server Then
			
			WriteAlertAsLogEvent(AlertText,Status, Object,ObjectMetadata);
			
		#EndIf	
				
		Message(AlertText, Status);
		
	#EndIf

EndFunction	

Procedure WriteAlertAsLogEvent(AlertText,Status, Object,ObjectMetadata)
	
	If Status = MessageStatus.Important  Then
		
		LogEventStatus = EventLogLevel.Error;
		
	ElsIf Status = MessageStatus.Information Then
		
		LogEventStatus = EventLogLevel.Warning;
		
	EndIf;	
	
	NoRefObject = False;
	Try
		ObjectRef = Object.Ref;
	Except
		NoRefObject = True;
	EndTry;	
	
	WriteLogEvent("ServerMessages",LogEventStatus, ObjectMetadata, ?(Object = Undefined Or NoRefObject,Object,ObjectRef) ,AlertText,?(TransactionActive(),EventLogEntryTransactionMode.Transactional,EventLogEntryTransactionMode.Independent));
	
EndProcedure	

Function AlertReturnPredefinedAttributesValueTableByObject(Object) Export
	
	NewValueTable = CreateAttributesValueTable();
	
	ObjectMetadata = Object.Metadata();
	
	// First check predefined attributes filling.
	If Metadata.Documents.Contains(ObjectMetadata)
		OR Metadata.Tasks.Contains(ObjectMetadata)
		OR Metadata.BusinessProcesses.Contains(ObjectMetadata) Then
		
		AttributesStructure = New Structure("Number, Date",Nstr("en='Number';pl='Numer';ru='Номер'"),Nstr("en='Date';pl='Data'"));
		NewValueTable = AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
		
	Else // Catalogs etc.
		
		AttributesStructure = New Structure();
		If ObjectMetadata.CodeLength >0 Then
			AttributesStructure.Insert("Code",Nstr("en='Code';pl='Kod';ru='Код'"));
		EndIf;
		If ObjectMetadata.DescriptionLength >0 Then
			AttributesStructure.Insert("Description",Nstr("en='Description';pl='Opis'"));
		EndIf;

		NewValueTable = AlertCreateAttributesValueTableFromStructure(AttributesStructure,Enums.AlertType.Error);
		
	EndIf;

	Return NewValueTable;
	
EndFunction	

// StringToParametrize - String with parameters names. Recommended to name parameters %P1,%P2- and so one 
// ParametersStructure - Structure which contains parameter name (without %-symbol) as key and parameters value as value 
Function ParametrizeString(StringToParametrize,ParametersStructure) Export

	Return CommonAtClientAtServer.ParametrizeString(StringToParametrize,ParametersStructure);
	
EndFunction

Function IsNotEqualValue(Value1,Value2) Export
	
	If ValueIsFilled(Value1) And ValueIsFilled(Value2) Then
		Return (Value1 <> Value2);
	Else
		Return False;
	EndIf;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// LOCAL FUNCTIONS

Procedure AlertObjectTabularPartAttributesValueTableValidation(Object, TabularPartName, TabularPartValueTable,Cancel = Undefined) 
	
	If TabularPartValueTable = Undefined OR TabularPartValueTable.Count() <=0 Then
		Return ;
	EndIf;	
	
	AlarmOnEmptyRow = TabularPartValueTable.Find("CheckNotEmpty","Name");
	
	If AlarmOnEmptyRow = Undefined OR AlarmOnEmptyRow.Type <> Enums.AlertsAttributesPropertyType.Property Then
		AlarmOnEmpty = False;
	Else
		AlarmOnEmpty = True;
	EndIf;
	
	TabularPartPresentation = Object.Metadata().TabularSections[TabularPartName].Presentation();
	TabularPart             = Object[TabularPartName];
	MetadataAttributes      = Object.Metadata().TabularSections[TabularPartName].Attributes;
	
	If TabularPart.Count() = 0 And AlarmOnEmpty  Then
		
		ErrorText = NStr("en=""Tabular part '"";pl=""Część tabelaryczna '"";ru=""Табличная часть '""") + TabularPartPresentation + NStr("en=''' cannot be empty!'; pl=''' nie może być pusta!';");
		WarningText = NStr("en=""Tabular part '"";pl=""Część tabelaryczna '"";ru=""Табличная часть '""") + TabularPartPresentation + NStr("en=""' is empty! Check, maybe it should be filled!"";pl=""' jest pusta! Sprawdź czy ona naprawde powinna być pusta!""");
		AlertText = ?(AlarmOnEmptyRow.Status = Enums.AlertType.Error,ErrorText,WarningText);
		AddAlert(AlertText,AlarmOnEmptyRow.Status,Cancel,Object);
		
	EndIf;
	
	For Each TabularPartRow In TabularPart Do
		
		MessageTextBegin = NStr("en=""Tabular part '"";pl=""Część tabelaryczna '"";ru=""Табличная часть '""") + TabularPartPresentation + NStr("en=""', line number "";pl=""', numer wiersza "";ru=""', номер строки """) + TrimAll(TabularPartRow.LineNumber) + ". ";
		
		For Each Row In TabularPartValueTable Do
			
			If Row.Type = Enums.AlertsAttributesPropertyType.Attribute Then
				
				If ValueIsNotFilled(TabularPartRow[Row.Name]) Then
					
					If IsBlankString(Row.Presentation) Then
						AttributePresentation = TrimAll(MetadataAttributes[Row.Name].Presentation());
					Else
						AttributePresentation = Row.Presentation;
					EndIf;	
					ErrorText = NStr("en=""Please, input attribute's value: '"";pl=""Wprowadź wartość atrybutu: '"";") + TrimAll(AttributePresentation) + "'!";
					WarningText = NStr("en=""Please, check attribute's value: '"";pl=""Sprawdź wartość atrybutu: '""") + TrimAll(AttributePresentation) + "'!" + NStr("en='''Maybe it should be filled!'; pl='''Czy on naprawde powinnien być pusty!';");
					AlertText = ?(Row.Status = Enums.AlertType.Error,ErrorText,WarningText);
					AddAlert(?(Row.AlertMessage = "",Row.BeginMessage + MessageTextBegin+AlertText,Row.BeginMessage + MessageTextBegin+Row.AlertMessage),Row.Status,Cancel,Object);
					
				EndIf;	
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// check UniqueAttributes
	UniqueAttributesRow = TabularPartValueTable.Find(Enums.AlertsAttributesPropertyType.UniqueAttributes, "Type");
	If UniqueAttributesRow <> Undefined Then
		ObjectsExtensionsAtServer.TableUniquenessRowValidation(Object, TabularPartName, UniqueAttributesRow.Name, Cancel, , , UniqueAttributesRow.Status);
	EndIf;
		
	
EndProcedure // ObjectTabularPartAttributesValidation()

Function CreateAttributesValueTable()
	
	NewValueTable = New ValueTable;
	NewValueTable.Columns.Add("Name",New TypeDescription("String"));
	NewValueTable.Columns.Add("Presentation",New TypeDescription("String"));
	NewValueTable.Columns.Add("Type",New TypeDescription("EnumRef.AlertsAttributesPropertyType"));
	NewValueTable.Columns.Add("Status",New TypeDescription("EnumRef.AlertType"));
	NewValueTable.Columns.Add("AlertMessage",New TypeDescription("String"));
	NewValueTable.Columns.Add("BeginMessage",New TypeDescription("String"));
	
	Return NewValueTable;
	
EndFunction	
