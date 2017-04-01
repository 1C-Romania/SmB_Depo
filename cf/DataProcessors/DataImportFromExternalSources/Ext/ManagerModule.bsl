#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OutputErrorsReport(SpreadsheetDocumentMessages, Errors)
	
	SpreadsheetDocumentMessages.Clear();
	
	Template					= GetTemplate("Errors");
	AreaHeader			= Template.GetArea("Header");
	AreaErrorOrdinary	= Template.GetArea("ErrorOrdinary");
	AreaErrorCritical	= Template.GetArea("ErrorCritical");
	
	SpreadsheetDocumentMessages.Put(AreaHeader);
	For Each Error IN Errors Do
		
		TemplateArea = ?(Error.Critical, AreaErrorCritical, AreaErrorOrdinary);
		TemplateArea.Parameters.Fill(Error);
		
		SpreadsheetDocumentMessages.Put(TemplateArea);
		
	EndDo;
	
EndProcedure

Procedure IsEmptyTabularDocument(SpreadsheetDocument, DenyTransitionNext)
	
	DenyTransitionNext = (SpreadsheetDocument.TableHeight < 1);
	
EndProcedure

Procedure CheckSpecificationFieldGroupsMandatoryForFilling(GroupsAndFields, Errors)
	
	GroupAndFieldCopy = GroupsAndFields.Copy();
	For Each FieldsGroup IN GroupAndFieldCopy.Rows Do
		
		If FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupMandatoryForFillingName() 
			OR FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			
			Continue;
			
		EndIf;
		
		UnselectedColumnNames = "";
		UnselectedColumnsInGroup = 0;
		IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
		For Each FieldsGroupField IN FieldsGroup.Rows Do 
			
			If FieldsGroupField.ColumnNumber = 0 Then
				
				If IsCustomFieldsGroup Then
					
					If FieldsGroupField.RequiredFilling Then
						
						// IN group mandatory field
						ErrorText = NStr("en='{%1} mandatory column is not selected';ru='Не выбрана обязательная колонка {%1}'");
						ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroupField.FieldPresentation);
						OccurrencePlace = NStr("en='Titles setting.';ru='Настройка заголовков.'");
						
						DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
						
					ElsIf FieldsGroup.GroupRequiredFilling Then // If a group is mandatory for filling but no field is selected
						
						UnselectedColumnsInGroup = UnselectedColumnsInGroup + 1;
						UnselectedColumnNames = UnselectedColumnNames + ?(IsBlankString(UnselectedColumnNames), "", ", ") + FieldsGroupField.FieldPresentation;
						
					EndIf;
					
				Else
					
					ErrorText = NStr("en='{%1} mandatory column is not selected';ru='Не выбрана обязательная колонка {%1}'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroupField.FieldPresentation);
					OccurrencePlace = NStr("en='Titles setting.';ru='Настройка заголовков.'");
					
					DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If IsCustomFieldsGroup 
			AND FieldsGroup.Rows.Count() = UnselectedColumnsInGroup Then
			
			ErrorText = NStr("en='For the {%1} fields group consisting of the set of {%2} columns you need to select at least one column in the imported data.';ru='Для группы полей {%1}, состоящей из набора колонок {%2}, в загружаемых данных необходимо выбрать минимум одну колонку.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroup.FieldsGroupName, UnselectedColumnNames);
			OccurrencePlace = NStr("en='Titles setting.';ru='Настройка заголовков.'");
			
			DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckFillingTabularDocumentAndFillFormTable(SpreadsheetDocument, DataMatchingTable, GroupsAndFields, Errors)
	
	DataMatchingTable.Clear();
	
	PostFix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	GroupAndFieldCopy = GroupsAndFields.Copy();
	
	For LineNumber = 2 To SpreadsheetDocument.TableHeight Do 
		
		NewDataRow = DataMatchingTable.Add();
		For Each FieldsGroup IN GroupAndFieldCopy.Rows Do
			
			UnfilledColumnsNames = "";
			UnfilledFieldsInGroup = 0;
			
			IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
			For Each FieldsGroupField IN FieldsGroup.Rows Do 
				
				CellValue = SpreadsheetDocument.GetArea(LineNumber, FieldsGroupField.ColumnNumber, LineNumber, FieldsGroupField.ColumnNumber).CurrentArea.Text;
				If IsCustomFieldsGroup Then
					
					NewDataRow[FieldsGroupField.FieldName] = CellValue;
					If Not ValueIsFilled(CellValue) Then
						
						If FieldsGroupField.RequiredFilling Then
							
							ErrorText = NStr("en='There are unfilled cells in the {%1} column. During processing these rows will be skipped.';ru='В колонке {%1} присутствуют незаполенные ячейки. При обработке данные строки будут пропущены.'");
							ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroupField.FieldPresentation);
							OccurrencePlace = NStr("en='Row No %1';ru='Строка № %1.'");
							OccurrencePlace = StringFunctionsClientServer.SubstituteParametersInString(OccurrencePlace, LineNumber);
							
							DataImportFromExternalSources.AddError(Errors, ErrorText, False, OccurrencePlace);
							
						EndIf;
						
						UnfilledFieldsInGroup = UnfilledFieldsInGroup + 1;
						UnfilledColumnsNames = UnfilledColumnsNames + ?(IsBlankString(UnfilledColumnsNames), "", ", ") + FieldsGroupField.FieldPresentation;
						
					EndIf;
					
				Else
					
					NewDataRow[FieldsGroupField.FieldName + PostFix] = CellValue;
					If Not ValueIsFilled(CellValue) 
						AND FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
						
						ErrorText = NStr("en='There are unfilled cells in the {%1} column. During processing these rows will be skipped.';ru='В колонке {%1} присутствуют незаполенные ячейки. При обработке данные строки будут пропущены.'");
						ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroupField.FieldPresentation);
						OccurrencePlace = NStr("en='Row No %1';ru='Строка № %1.'");
						OccurrencePlace = StringFunctionsClientServer.SubstituteParametersInString(OccurrencePlace, LineNumber);
						
						DataImportFromExternalSources.AddError(Errors, ErrorText, False, OccurrencePlace);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
			If IsCustomFieldsGroup
				AND FieldsGroup.Rows.Count() <> 0 // for groups optional for filling in
				AND FieldsGroup.Rows.Count() = UnfilledFieldsInGroup Then
				
				ErrorText = NStr("en='{%1} fields group consisting of the set of {%2} selected columns has rows with unfilled mandatory attributes. During data processing such rows will be skipped.';ru='В группе полей {%1}, состоящей из набора выбранных колонок {%2}, присутствуют строки c незаполенными обязательными реквизитами. При обработке данных такие строки будут пропущены.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldsGroup.FieldsGroupName, UnfilledColumnsNames);
				OccurrencePlace = NStr("en='Row No %1';ru='Строка № %1.'");
				OccurrencePlace = StringFunctionsClientServer.SubstituteParametersInString(OccurrencePlace, LineNumber);
				
				DataImportFromExternalSources.AddError(Errors, ErrorText, False, OccurrencePlace);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure HasUnfilledMandatoryColumns(SpreadsheetDocument, DataMatchingTable, DataLoadSettings, Errors)
	Var GroupsAndFields;
	
	DataImportFromExternalSources.CreateAndFillGroupAndFieldsByObjectNameTree(DataLoadSettings.FillingObjectFullName, GroupsAndFields, DataLoadSettings.IsTabularSectionImport);
	DataImportFromExternalSources.FillColumnNumbersInMandatoryFieldsAndGroupsTree(GroupsAndFields, SpreadsheetDocument);
	
	CheckSpecificationFieldGroupsMandatoryForFilling(GroupsAndFields, Errors);
	If Errors.Find(True, "Critical") = Undefined Then
		
		DataImportFromExternalSources.DeleteUnselectedFieldsInGroupsMadatoryForFilling(GroupsAndFields);
		CheckFillingTabularDocumentAndFillFormTable(SpreadsheetDocument, DataMatchingTable, GroupsAndFields, Errors);
		
	EndIf;
	
EndProcedure

Procedure PreliminarilyDataProcessor(SpreadsheetDocument, DataMatchingTable, DataLoadSettings, SpreadsheetDocumentMessages, SkipPage, DenyTransitionNext) Export
	Var Errors;
	
	DataImportFromExternalSources.CreateErrorsDescriptionTable(Errors);
	
	IsEmptyTabularDocument(SpreadsheetDocument, DenyTransitionNext);
	If DenyTransitionNext Then
		
		ErrorText = NStr("en='Imported data is not filled in...';ru='Незаполнены импортируемые данные...'");
		DataImportFromExternalSources.AddError(Errors, ErrorText);
		
	Else
		
		HasUnfilledMandatoryColumns(SpreadsheetDocument, DataMatchingTable, DataLoadSettings, Errors);
		
	EndIf;
	
	SkipPage = (Errors.Count() < 1);
	If Not SkipPage Then
		
		DenyTransitionNext = (Errors.Find(True, "Critical") <> Undefined);
		OutputErrorsReport(SpreadsheetDocumentMessages, Errors);
		
	EndIf;
	
EndProcedure

Procedure AddMatchTableColumns(ThisObject, DataMatchingTable, DataLoadSettings) Export
	Var GroupsAndFields;
	
	If DataMatchingTable.Unload().Columns.Count() > 0 Then
		
		Return;
		
	EndIf;
	
	If Not DataLoadSettings.IsTabularSectionImport Then
		
		ManagerObject = Undefined;
		DataImportFromExternalSources.GetManagerByFillingObjectName(DataLoadSettings.FillingObjectFullName, ManagerObject);
		AttributesToLock = ManagerObject.GetObjectAttributesBeingLocked();
		
	EndIf;
	
	DataImportFromExternalSources.CreateAndFillGroupAndFieldsByObjectNameTree(DataLoadSettings.FillingObjectFullName, GroupsAndFields, DataLoadSettings.IsTabularSectionImport);
	
	AttributeArray= New Array;
	AttributePath	= "DataMatchingTable";
	MandatoryFieldsGroup = Undefined;
	OptionalFieldsGroup = Undefined;
	ServiceFieldsGroup = Undefined;
	For Each FieldsGroup IN GroupsAndFields.Rows Do
		
		IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
		If IsCustomFieldsGroup Then
			
			AddAttributesFromCustomFieldsGroup(ThisObject, FieldsGroup, AttributePath, AttributesToLock);
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
			
			MandatoryFieldsGroup = FieldsGroup;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupMandatoryForFillingName() Then
			
			OptionalFieldsGroup = FieldsGroup;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			
			ServiceFieldsGroup = FieldsGroup;
			
		EndIf;
		
	EndDo;
	
	AddMandatoryAttributes(ThisObject, MandatoryFieldsGroup, AttributePath, AttributesToLock);
	AddOptionalAttributes(ThisObject, OptionalFieldsGroup, AttributePath, AttributesToLock);
	AddServiceAttributes(ThisObject, ServiceFieldsGroup, AttributePath);
	
	DataImportFromExternalSourcesOverridable.AfterAddingItemsToMatchesTables(ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesOverridable.AddConditionalMatchTablesDesign(ThisObject, AttributePath, DataLoadSettings);
	
EndProcedure

//:::Work with attributes and items of assistant forms

Procedure AddAttributesFromCustomFieldsGroup(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add("Group" + FieldsGroup.FieldsGroupName, Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Vertical;
	FirstLevelGroup.ShowTitle = False;
	
	NewAttributeGroup = New FormAttribute(FieldsGroup.FieldsGroupName, FieldsGroup.DerivedValueType, AttributePath, FieldsGroup.FieldsGroupName);
	
	AttributeArray = New Array;
	AttributeArray.Add(NewAttributeGroup);
	ThisObject.ChangeAttributes(AttributeArray);
	
	NewItem 				= Items.Add(FieldsGroup.FieldsGroupName, Type("FormField"), FirstLevelGroup);
	NewItem.Type			= FormFieldType.InputField;
	NewItem.DataPath	= "DataMatchingTable." + FieldsGroup.FieldsGroupName;
	NewItem.Title		= FieldsGroup.FieldPresentation;
	NewItem.EditMode = ColumnEditMode.Enter;
	NewItem.MarkIncomplete = FieldsGroup.GroupRequiredFilling;
	NewItem.AutoMarkIncomplete = FieldsGroup.GroupRequiredFilling;
	NewItem.CreateButton = False;
	
	SecondLevelGroup = Items.Add("GroupIncoming" + FieldsGroup.FieldsGroupName, Type("FormGroup"), FirstLevelGroup);
	SecondLevelGroup.Group = ColumnsGroup.InCell;
	SecondLevelGroup.ShowTitle = False;
	
	For Each GroupRow IN FieldsGroup.Rows Do
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = True;
		NewItem.Width 		= 4;
		NewItem.HorizontalStretch = False;
		
	EndDo;
	
EndProcedure

Procedure AddMandatoryAttributes(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add(DataImportFromExternalSources.FieldsMandatoryForFillingGroupName(), Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Horizontal;
	FirstLevelGroup.ShowTitle = False;
	
	PostFix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	
	AttributeArray = New Array;
	For Each GroupRow IN FieldsGroup.Rows Do
		
		SecondLevelGroup = Items.Add("Group" + GroupRow.FieldName, Type("FormGroup"), FirstLevelGroup);
		SecondLevelGroup.Group = ColumnsGroup.Vertical;
		SecondLevelGroup.ShowTitle = False;
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		NewAttribute = New FormAttribute(GroupRow.FieldName + PostFix, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = False;
		NewItem.MarkIncomplete = True;
		NewItem.AutoMarkIncomplete = True;
		NewItem.CreateButton = False;
		
		If AttributesToLock <> Undefined
			AND AttributesToLock.Find(GroupRow.FieldName) = Undefined Then
			
			NewItem.HeaderPicture = PictureLib.ExclamationMarkGray;
			
		EndIf;
		
		NewItem 				= Items.Add(GroupRow.FieldName + PostFix, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName + PostFix;
		NewItem.Title		= " ";//GroupRow.FieldsPresentation + PostFix;
		NewItem.ReadOnly = True;
		NewItem.MarkIncomplete = False;
		
	EndDo;
	
EndProcedure

Procedure AddOptionalAttributes(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add(DataImportFromExternalSources.FieldsGroupMandatoryForFillingName(), Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Horizontal;
	FirstLevelGroup.ShowTitle = False;
	
	PostFix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	
	AttributeArray = New Array;
	For Each GroupRow IN FieldsGroup.Rows Do
		
		SecondLevelGroup = Items.Add("Group" + GroupRow.FieldName, Type("FormGroup"), FirstLevelGroup);
		SecondLevelGroup.Group = ColumnsGroup.Vertical;
		SecondLevelGroup.ShowTitle = False;
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		NewAttribute = New FormAttribute(GroupRow.FieldName + PostFix, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = False;
		NewItem.CreateButton = False;
		
		If AttributesToLock <> Undefined
			AND AttributesToLock.Find(GroupRow.FieldName) <> Undefined Then
			
			NewItem.HeaderPicture = PictureLib.UnavailableFieldsInformtion;
			
		EndIf;
		
		NewItem 				= Items.Add(GroupRow.FieldName + PostFix, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName + PostFix;
		NewItem.Title		= " "; // GroupRow.FieldsPresentation + PostFix;
		NewItem.ReadOnly = True;
		
	EndDo;
	
EndProcedure

Procedure AddServiceAttributes(ThisObject, FieldsGroup, AttributePath)
	
	AttributeArray = New Array;
	For Each GroupRow IN FieldsGroup.Rows Do
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, GroupRow.FieldName);
		AttributeArray.Add(NewAttribute);
		
	EndDo;
	
	ThisObject.ChangeAttributes(AttributeArray);
	
EndProcedure


//:::Excel 2007 Format (xlsx)

Function RowToNumber(Val Value, DefaultValue = 0)
	
	Try
		
		If Value = Undefined OR Value ="0" Then
			
			// Process the presentation of a default value separately
			Result =DefaultValue;
			
		Else
			
			NumberPower = 0;
			Position = Find(Value, "E");
			If Position > 0 Then
				NumberPower = Mid(Value, Position + 1);
				Value = Left(Value, Position - 1);
			EndIf;
			
			TargetType = New TypeDescription("Number");
			Result = TargetType.AdjustValue(Value);
			
			If NumberPower <> 0 Then
				Result = Result * Pow(10, NumberPower);
			EndIf;
			
		EndIf;
		
	Except
		
		Result = Value;
		
	EndTry;
	
	Return Result;
	
EndFunction

Procedure UnpackFile(File, Folder)
	
	ZipArchive = New ZipFileReader;
	ZipArchive.Open(File);
	ZipArchive.ExtractAll(Folder, ZIPRestoreFilePathsMode.Restore);
	
EndProcedure

Function GetLettersArray()
	LettersArray = New Array;
	LettersArray.Add("A"); // 1
	LettersArray.Add("B");
	LettersArray.Add("C");
	LettersArray.Add("D");
	LettersArray.Add("E");
	LettersArray.Add("F");
	LettersArray.Add("G");
	LettersArray.Add("H");
	LettersArray.Add("I");
	LettersArray.Add("J"); // 10
	LettersArray.Add("K");
	LettersArray.Add("L");
	LettersArray.Add("M");
	LettersArray.Add("N");
	LettersArray.Add("O");
	LettersArray.Add("P");
	LettersArray.Add("Q");
	LettersArray.Add("R");
	LettersArray.Add("S");
	LettersArray.Add("T"); // 20
	LettersArray.Add("U");
	LettersArray.Add("V");
	LettersArray.Add("W");
	LettersArray.Add("X");
	LettersArray.Add("Y");
	LettersArray.Add("Z");
	LettersArray.Add("AA");
	LettersArray.Add("AB");
	LettersArray.Add("AC");
	LettersArray.Add("AD"); // 30
	LettersArray.Add("AE");
	LettersArray.Add("AF");
	LettersArray.Add("AG");
	LettersArray.Add("AH");
	LettersArray.Add("AI");
	LettersArray.Add("AJ");
	LettersArray.Add("AK");
	LettersArray.Add("AL");
	LettersArray.Add("AM");
	LettersArray.Add("AN"); // 40
	LettersArray.Add("AO");
	LettersArray.Add("AP");
	LettersArray.Add("AQ");
	LettersArray.Add("AR");
	LettersArray.Add("AS");
	LettersArray.Add("AT");
	LettersArray.Add("AU");
	LettersArray.Add("AV");
	LettersArray.Add("AW");
	LettersArray.Add("AX"); // 50
	//LettersArray.Add (AY);
	//LettersArray.Add (AZ)
	
	Return LettersArray;
	
EndFunction

Function ReadRowsList(RowsFile)
	
	//
	//::: SB Take from SSL after correcting the error of XML parsing (DSS 00034078)
	//
	
	Rows 					= New ValueList;
	ValueListItem	= Undefined;
	FilePresenceCheck	= New File(RowsFile);
	
	If FilePresenceCheck.Exist() Then
		
		_XML = New XMLReader;
		_XML.OpenFile(RowsFile);
		While _XML.Read() Do
			
			If _XML.NodeType = XMLNodeType.StartElement Then
				
				If _XML.Name = "sst" Then
					
					RecCount = _XML.GetAttribute("uniqueCount"); // Quantity of fields (not used at the current stage)
					
				ElsIf _XML.Name = "si" Then
					
					ValueListItem = Rows.Add("");
					
				EndIf;
				
			ElsIf _XML.NodeType = XMLNodeType.Text Then
				
				ValueListItem.Value = ValueListItem.Value + ?(ValueIsFilled(ValueListItem.Value), _XML.Value, TrimL(_XML.Value));
				
			EndIf;
			
		EndDo;
		_XML.Close();
		
	EndIf;
	
	Return Rows;
	
EndFunction

Function GetDataTree(File)
	
	DataTree = New ValueTree;
	DataTree.Columns.Add("Object");
	DataTree.Columns.Add("Value");
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(File);
	
	CurItem = Undefined;
	CurBase = Undefined;
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ImportMode = XMLReader.Name;
			
			If CurItem = Undefined Then
				CurItem = DataTree.Rows.Add();
				CurItem.Object = ImportMode;
			Else
				CurItem = CurItem.Rows.Add();
				CurItem.Object = ImportMode;					
			EndIf;
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			If CurItem = Undefined Then
				CurItem = Undefined;
			Else
				CurItem = CurItem.Parent;
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			CurItem.Value = XMLReader.Value;
		EndIf;
		
		For IndexOf = 0 To XMLReader.AttributeCount() - 1 Do
			String = CurItem.Rows.Add();
			String.Object = XMLReader.AttributeName(IndexOf);
			String.Value = XMLReader.AttributeValue(IndexOf);
		EndDo;
	EndDo;
	
	XMLReader.Close();
	
	Return DataTree;
EndFunction

Function ReadFormatsList(FormatsFile)
	
	Xml = New XMLReader;
	Xml.OpenFile(FormatsFile);
	FormatsDescription = New Map;
	
	While Xml.Read() Do
		// SB
		If Xml.NodeType = XMLNodeType.StartElement AND Xml.Name = "cellXfs" Then
			
			Position = 0;
			While Xml.Read() Do 
				
				If Xml.NodeType = XMLNodeType.StartElement and Xml.Name = "xf" Then
					
					// Description of date format http://social.msdn.microsoft.com/Forums/office/en-US/e27aaf16-b900-4654-8210-83c5774a179c/xlsx-numfmtid-predefined-id-14-doesnt-match?forum=oxmlsdk
					If Xml.AttributeValue("numFmtId") <> Undefined Then 
						
						FormatsDescription.Insert(Position, "String"); // Take a 0 common format as a row
						
						FormatNumber =  Number(Xml.AttributeValue("numFmtId"));
						If FormatNumber > 0 AND FormatNumber < 12 Then
							
							FormatsDescription[Position] = "Number";
							
						ElsIf FormatNumber > 13 AND FormatNumber <= 17 Then
							
							FormatsDescription[Position] = "Date";
							
						ElsIf FormatNumber >= 18 AND FormatNumber <= 21 Then
							
							FormatsDescription[Position] = "Time";
							
						ElsIf FormatNumber = 22 Then
							
							FormatsDescription[Position] = "DateTime";
							
						ElsIf FormatNumber >= 164 Then // Leave custom formats in a form of a text for now, but you need to see by the signs.
							
							FormatsDescription[Position] = "String";
							
						EndIf;
						
					EndIf;
					Position = Position + 1;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		// End. SB
		
	EndDo;
	
	Xml.Close();
	
	Return FormatsDescription;
	
EndFunction

Procedure ImportExcel2007FormatData(TempFileName, SpreadsheetDocument, FillingObjectFullName) Export
	
	File = New File(TempFileName);
	If Not File.Exist() Then
		
		Return;
		
	EndIf;
	
	ExcelFile = TempFileName;
	TemporaryDirectory = TempFilesDir() + GetPathSeparator() + "excel2007";
	DeleteFiles(TemporaryDirectory);
	
	UnpackFile(ExcelFile, TemporaryDirectory);
	
	RowsFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"sharedStrings.xml";
	RowList = ReadRowsList(RowsFile);
	
	FormatsFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"styles.xml";
	FormatList = ReadFormatsList(FormatsFile);
	
	NumberWorksheet = 1;
	SheetFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() + "worksheets" + GetPathSeparator() + "sheet" + NumberWorksheet + ".xml";
	File = New File(SheetFile);
	If Not File.Exist() Then
		
		Return;
		
	EndIf;
	
	LettersArray = GetLettersArray();
	DataTree = GetDataTree(SheetFile);
	
	Table = New ValueTable;
	
	//create columns (selection restriction: 50)
	Counter = 0;
	Columns = DataTree.Rows.Find("dimension", "Object", True);
	For Each String IN Columns.Rows Do
		
		If String.Object = "ref" Then
			
			Range = String.Value;
			
			CharacterIndex = StrLen(Range);
			LastColumnName = "";
			While CharacterIndex > 0 Do
				
				CharacterFromRow = Mid(Range, CharacterIndex, 1);
				PositionInArray = LettersArray.Find(CharacterFromRow);
				If PositionInArray <> Undefined Then
					
					LastColumnName = CharacterFromRow + LastColumnName;
					
				ElsIf Not IsBlankString(LastColumnName) Then
					
					Break;
					
				EndIf;
				
				CharacterIndex = CharacterIndex - 1;
				
			EndDo;
			
			PositionInArray = LettersArray.Find(LastColumnName);
			PositionInArray = ?(PositionInArray = Undefined, 49, PositionInArray);
			For IndexOf = 0 To PositionInArray Do
				
				Table.Columns.Add(LettersArray[IndexOf]);
				
			EndDo;
			
			Break;
			
		EndIf;
		
	EndDo;
	
	//read rows
	RowsPag = DataTree.Rows.Find("sheetData", "Object", True);
	For Each String IN RowsPag.Rows Do
		
		NewRow = Table.Add();
		
		For Each Column IN String.Rows Do
			
			If Column.Object <> "c" Then
				
				Continue;
				
			EndIf;
			
			CellValue = Undefined;
			
			ValueStr = Column.Rows.Find("v", "Object");
			If ValueStr <> Undefined Then
				
				CellValue = ValueStr.Value;
				
			EndIf;
			
			CellContainsText = False; // SB
			ValueStr = Column.Rows.Find("t", "Object");
			If ValueStr <> Undefined AND ValueStr.Value = "s" AND CellValue <> Undefined Then
				
				CellContainsText = True; // SB
				Position = Number(CellValue); 
				If RowList.Count() > Position Then
					
					CellValue = RowList.Get(Position).Value;
					
				EndIf;
				
			EndIf;
			
			withObject = Column.Rows.Find("s", "Object");
			If withObject <> Undefined Then
				
				ValueStr = RowToNumber(Column.Rows.Find("s", "Object").Value, -1);
				If ValueStr >= 0 Then
					
					FormatName = FormatList.Get(ValueStr);
					If FormatName = "Date" OR FormatName = "DateTime" OR FormatName = "Time" Then
						
						If ValueIsFilled(CellValue) AND Not CellContainsText Then // SB.Despite the format you can write everything to a cell.
							
							SeparatorPosition = Find(CellValue, ".");
							If SeparatorPosition > 0 Then 
								
								DaysNumber = RowToNumber(Left(CellValue, SeparatorPosition - 1)) * 86400 - 2 * 86400;
								CountSeconds = RowToNumber(Mid(CellValue, SeparatorPosition + 1)) - 2 * 60;
								
							Else
								
								DaysNumber = RowToNumber(CellValue) * 86400 - 2 * 86400;
								CountSeconds = 0;
								
							EndIf;
							
							ReceivedDate = Date(1900, 1, 1, 0, 0, 0) + DaysNumber + CountSeconds;
							If FormatName = "Date" Then 
								
								CellValue = Format(ReceivedDate, "DLF=D");
								
							ElsIf FormatName = "DateTime" Then 
								
								CellValue = Format(ReceivedDate, "DLF=DT");
								
							ElsIf FormatName = "Time" Then 
								
								CellValue = Format(ReceivedDate, "DLF=T");
								
							EndIf;
							
						EndIf;
						
					Else
						
						If FormatName = "Number" Then
							
							ConvertedValue = RowToNumber(CellValue);
							If TypeOf(ConvertedValue) = Type("Number") Then
								
								CellValueNumber = Format(ConvertedValue, "NGS=; NG=0");
								If ValueIsFilled(CellValueNumber) Then
									
									CellValue = CellValueNumber;
									
								Else
									
									CellValue = Format(CellValueNumber, "NGS=; NG=0");
									
								EndIf;
								
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			//search column
			ValueStr = Column.Rows.Find("r", "Object");
			If ValueStr <> Undefined Then
				
				ColumnName = ValueStr.Value;
				
			EndIf;
			
			RowIndex = Undefined;
			Counter = LettersArray.Count();
			While Counter > 0 Do 
				
				Counter = Counter - 1;
				If Find(ColumnName, LettersArray[Counter])>0 Then
					
					RowIndex = Counter;
					Counter = 0;
					
				EndIf;
				
			EndDo;
			
			NewRow[LettersArray[RowIndex]] = CellValue;
			
		EndDo;
		
	EndDo;
	
	DataImportFromExternalSources.DataFromValuesTableToTabularDocument(Table, SpreadsheetDocument, FillingObjectFullName);
	
EndProcedure

#EndIf