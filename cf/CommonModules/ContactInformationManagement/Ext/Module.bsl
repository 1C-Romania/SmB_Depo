////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Handlers of form events and object module.

// Handler for the OnCreateAtServer form event.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form                - ManagedForm - Object-owner form is designed to output contact.
//                           Information.
//    Object               - Arbitrary - Object-owner of contact information.
//    TitleLocationCI - FormItemTitleLocation - It can
//                                                             take values FormItemTitleLocation.Left
//                                                             or FormItemTitleLocation.Top (by default).
//
Procedure OnCreateAtServer(Form, Object, ItemNameForPlacement = "", TitleLocationCI = "",
	Val ExcludedKinds = Undefined, DeferredInitialization = False) Export
	
	If ExcludedKinds = Undefined Then
		ExcludedKinds = New Array;
	EndIf;
	
	ArrayOfAddedDetails = New Array;
	CheckContactInformationAttributesPresence(Form, ArrayOfAddedDetails);
	
	// Get CI kinds list
	
	ObjectReference = Object.Ref;
	ObjectMetadata = ObjectReference.Metadata();
	FullMetadataObjectName = ObjectMetadata.FullName();
	NameCIKindsGroups = StrReplace(FullMetadataObjectName, ".", "");
	CIKindsGroup = Catalogs.ContactInformationTypes[NameCIKindsGroups];
	ObjectName = ObjectMetadata.Name;
	
	If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("RowIdTableParts") = Undefined Then
		DataRowIDOfTableParts = "0";
	Else
		DataRowIDOfTableParts = "ISNULL(ContactInformation.TabularSectionRowID, 0)";
	EndIf;
	
	Query = New Query;
	If ValueIsFilled(ObjectReference) Then
		Query.Text ="
		|SELECT
		|	ContactInformationTypes.Ref                       AS Kind,
		|	ContactInformationTypes.PredefinedDataName    AS PredefinedDataName,
		|	ContactInformationTypes.Type                          AS Type,
		|	ContactInformationTypes.RequiredFilling       AS RequiredFilling,
		|	ContactInformationTypes.ToolTip                    AS ToolTip,
		|	ContactInformationTypes.Description                 AS Description,
		|	ContactInformationTypes.EditInDialogOnly AS EditInDialogOnly,
		|	ContactInformationTypes.IsFolder                    AS ThisAttributeOfTabularSection,
		|	ContactInformationTypes.AdditionalOrderingAttribute    AS AdditionalOrderingAttribute,
		|	ISNULL(ContactInformation.Presentation, """")    AS Presentation,
		|	ISNULL(ContactInformation.FieldsValues, """")    AS FieldsValues,
		|	ISNULL(ContactInformation.LineNumber, 0)         AS LineNumber,
		|	" + DataRowIDOfTableParts + "      AS RowID,
		|	CAST("""""""" AS String(200))                    AS AttributeName,
		|	CAST("""" AS String)                             AS Comment
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|LEFT JOIN 
		|	" +  FullMetadataObjectName + ".ContactInformation AS ContactInformation
		|ON ContactInformation.Ref = &Owner
		|	AND ContactInformationTypes.Ref = ContactInformation.Kind
		|WHERE
		|	NOT ContactInformationTypes.DeletionMark 
		|	AND (ContactInformationTypes.Parent = &CIKindsGroup
		|	OR ContactInformationTypes.Parent.Parent = &CIKindsGroup) 
		|ORDER BY ContactInformationTypes.Ref HIERARCHY
		|";
	Else
		Query.Text ="
		|SELECT
		|	ContactInformation.Presentation               AS Presentation,
		|	ContactInformation.FieldsValues               AS FieldsValues,
		|	ContactInformation.LineNumber                 AS LineNumber,
		|	ContactInformation.Kind                         AS Kind,
		|	" + DataRowIDOfTableParts + " AS RowIdTableParts
		|INTO 
		|	ContactInformation
		|FROM
		|	&TableContactInformation AS ContactInformation
		|INDEX BY
		|	Kind
		|;////////////////////////////////////////////////////////////////////////////////
		|
		|SELECT
		|	ContactInformationTypes.Ref                       AS Kind,
		|	ContactInformationTypes.PredefinedDataName    AS PredefinedDataName,
		|	ContactInformationTypes.Type                          AS Type,
		|	ContactInformationTypes.RequiredFilling       AS RequiredFilling,
		|	ContactInformationTypes.ToolTip                    AS ToolTip,
		|	ContactInformationTypes.Description                 AS Description,
		|	ContactInformationTypes.EditInDialogOnly AS EditInDialogOnly,
		|	ContactInformationTypes.IsFolder                    AS ThisAttributeOfTabularSection,
		|	ContactInformationTypes.AdditionalOrderingAttribute    AS AdditionalOrderingAttribute,
		|	ISNULL(ContactInformation.Presentation, """")    AS Presentation,
		|	ISNULL(ContactInformation.FieldsValues, """")    AS FieldsValues,
		|	ISNULL(ContactInformation.LineNumber, 0)         AS LineNumber,
		|	" + DataRowIDOfTableParts + "      AS RowID,
		|	CAST("""""""" AS String(200))                    AS AttributeName,
		|	CAST("""" AS String)                             AS Comment
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|LEFT JOIN 
		|	ContactInformation AS ContactInformation
		|ON 
		|	ContactInformationTypes.Ref = ContactInformation.Kind
		|WHERE
		|	NOT ContactInformationTypes.DeletionMark
		|	AND (
		|		ContactInformationTypes.Parent = &CIKindsGroup 
		|		OR ContactInformationTypes.Parent.Parent = &CIKindsGroup)
		|ORDER BY
		|	ContactInformationTypes.Ref HIERARCHY
		|";
		
		Query.SetParameter("TableContactInformation", Object.ContactInformation.Unload());
	EndIf;
	
	Query.SetParameter("CIKindsGroup", CIKindsGroup);
	Query.SetParameter("Owner", ObjectReference);
	
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy).Rows;
	SetPrivilegedMode(False);
	
	ContactInformation.Sort("AdditionalOrderingAttribute, LineNumber");
	String500 = New TypeDescription("String", , New StringQualifiers(500));
	
	CreatedAttributes = CommonUseClientServer.CopyArray(ExcludedKinds);
	
	For Each ContactInformationObject In ContactInformation Do
		
		If ContactInformationObject.ThisAttributeOfTabularSection Then
			
			NameKindKI = ContactInformationObject.PredefinedDataName;
			Pos = Find(NameKindKI, ObjectName);
			
			TabularSectionName = Mid(NameKindKI, Pos + StrLen(ObjectName));
			
			PreviousKind = Undefined;
			AttributeName = "";
			
			ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
			
			For Each CIRow In ContactInformationObject.Rows Do
				
				ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
				
				CurrentKind = CIRow.Type;
				
				If CurrentKind <> PreviousKind Then
					
					AttributeName = "ContactInformationField" + TabularSectionName + ContactInformationObject.Rows.IndexOf(CIRow);
					
					PathDetails = "Object." + TabularSectionName;
					
					ArrayOfAddedDetails.Add(New FormAttribute(AttributeName, String500, PathDetails, CIRow.Description, True));
					ArrayOfAddedDetails.Add(New FormAttribute(AttributeName + "FieldsValues", New TypeDescription("ValueList, String"), PathDetails,, True));
					PreviousKind = CurrentKind;
					
				EndIf;
				
				CIRow.AttributeName = AttributeName;
				
			EndDo;
			
		Else
			
			IndexOf = CreatedAttributes.Find(ContactInformationObject.Type);
			
			If IndexOf = Undefined Then
				ContactInformationObject.AttributeName = "ContactInformationField" + ContactInformation.IndexOf(ContactInformationObject);
				If Not DeferredInitialization Then
					ArrayOfAddedDetails.Add(New FormAttribute(ContactInformationObject.AttributeName, String500, , ContactInformationObject.Description, True));
				EndIf;
			Else
				ContactInformationObject.AttributeName = "ContactInformationField" + ContactInformationObject.PredefinedDataName;
				CreatedAttributes.Delete(IndexOf);
			EndIf;
			
			// If you detect recognition errors, do not interrupt generation.
			Try
				ContactInformationObject.Comment = ContactInformationComment(ContactInformationObject.FieldsValues);
			Except
				WriteLogEvent(ContactInformationManagementService.EventLogMonitorEvent(),
				EventLogLevel.Error, , ContactInformationObject.FieldsValues, 
				DetailErrorDescription(ErrorInfo()));
				CommonUseClientServer.MessageToUser(
				NStr("en='Incorrect format of contact information.';ru='Некорректный формат контактной информации.'"), ,
				ContactInformationObject.AttributeName);
			EndTry;
		EndIf;
		
	EndDo;
	
	// Add new attributes
	If ArrayOfAddedDetails.Count() > 0 Then
		Form.ChangeAttributes(ArrayOfAddedDetails);
	EndIf;
	
	Form.ContactInformationParameters = New Structure;
	Form.ContactInformationParameters.Insert("TitleLocation", String(TitleLocationCI));
	Form.ContactInformationParameters.Insert("GroupForPosting", ItemNameForPlacement);
	Form.ContactInformationParameters.Insert("AddedItemsList", New ValueList);
	Form.ContactInformationParameters.Insert("AddedElements", New ValueList);
	Form.ContactInformationParameters.Insert("ExcludedKinds", ExcludedKinds);
	Form.ContactInformationParameters.Insert("DeferredInitialization", DeferredInitialization);
	Form.ContactInformationParameters.Insert("ExecutedDeferredInitialization", False);
	
	PreviousKind = Undefined;
	
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	QuantityAddresses = ContactInformation.FindRows(Filter).Count();
	
	// Create items on the form and fill in attribute values.
	Parent = ?(IsBlankString(ItemNameForPlacement), Form, Form.Items[ItemNameForPlacement]);
	
	// Creating groups for contact information.
	CompositionGroup = VarGroup("CompositionGroupContactInformation",
	Form, Parent, ChildFormItemsGroup.Horizontal, 5);
	TitlesGroup = VarGroup("GroupHeadersContactInformation",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	GroupInputFields = VarGroup("FieldsGroupEnteringContactInformation",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	ActionsGroup = VarGroup("GroupActionsContactInformation",
	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	
	TitleLeft = TitleLeft(Form, TitleLocationCI);
	CraftedItems = CommonUseClientServer.CopyArray(ExcludedKinds);
	
	For Each CIRow In ContactInformation Do
		
		If CIRow.ThisAttributeOfTabularSection Then
			
			NameKindKI = CommonUse.PredefinedName(CIRow.Type);
			Pos = Find(NameKindKI, ObjectName);
			
			TabularSectionName = Mid(NameKindKI, Pos + StrLen(ObjectName));
			
			PreviousTSKind = Undefined;
			
			For Each RowOfTabularSectionKI In CIRow.Rows Do
				
				KindOfTS = RowOfTabularSectionKI.Type;
				
				If KindOfTS <> PreviousTSKind Then
					
					TabularSectionGroup = Form.Items[TabularSectionName + "GroupContactInformation"];
					
					Item = Form.Items.Add(RowOfTabularSectionKI.AttributeName, Type("FormField"), TabularSectionGroup);
					Item.Type = FormFieldType.InputField;
					Item.DataPath = "Object." + TabularSectionName + "." + RowOfTabularSectionKI.AttributeName;
					
					If ForContactInformationTypeAvailableEditInDialog(RowOfTabularSectionKI.Type) Then
						Item.ChoiceButton = True;
						If KindOfTS.EditInDialogOnly Then
							Item.TextEdit = False;
						EndIf;
						
						Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
					EndIf;
					Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
					
					If KindOfTS.RequiredFilling Then
						Item.AutoMarkIncomplete = True;
					EndIf;
					
					AddItemDescription(Form, RowOfTabularSectionKI.AttributeName, 2);
					AddAttributeToDescription(Form, RowOfTabularSectionKI, False, True);
					PreviousTSKind = KindOfTS;
					
				EndIf;
				
				Filter = New Structure;
				Filter.Insert("RowIdTableParts", RowOfTabularSectionKI.RowID);
				
				TableRows = Form.Object[TabularSectionName].FindRows(Filter);
				
				If TableRows.Count() = 1 Then
					
					TableRow = TableRows[0];
					TableRow[RowOfTabularSectionKI.AttributeName] = RowOfTabularSectionKI.Presentation;
					TableRow[RowOfTabularSectionKI.AttributeName + "FieldsValues"] = RowOfTabularSectionKI.FieldsValues;
					
				EndIf;
				
			EndDo;
			
			Continue;
			
		EndIf;
		
		IsComment = ValueIsFilled(CIRow.Comment);
		AttributeName = CIRow.AttributeName;
		ItemIndex = CraftedItems.Find(CIRow.Kind);
		StaticItem = ItemIndex <> Undefined;
		
		IsNewCIKind = (CIRow.Kind <> PreviousKind);
		
		If DeferredInitialization Then
			
			AddAttributeToDescription(Form, CIRow, IsNewCIKind,, StaticItem);
			If StaticItem Then
				CraftedItems.Delete(ItemIndex);
			EndIf;
			Continue;
			
		EndIf;
		
		If Not StaticItem Then
			
			If TitleLeft Then
				
				TitleFunc(Form, CIRow.Type, AttributeName, TitlesGroup, CIRow.Description, IsNewCIKind, IsComment);
				
			EndIf;
			
			InputField(Form, CIRow.EditInDialogOnly, CIRow.Type, AttributeName, CIRow.ToolTip, IsNewCIKind, CIRow.RequiredFilling);
			
			// Output comment
			If IsComment Then
				
				NameComments = "Comment" + AttributeName;
				Comment(Form, CIRow.Comment, NameComments, GroupInputFields);
				
			EndIf;
			
			// Endcap if fields has title above.
			If Not TitleLeft AND IsNewCIKind Then
				
				NameDecoration = "DecorationTop" + AttributeName;
				Decoration = Form.Items.Add(NameDecoration, Type("FormDecoration"), ActionsGroup);
				AddItemDescription(Form, NameDecoration, 2);
				
			EndIf;
			
			Action(Form, CIRow.Type, AttributeName, ActionsGroup, QuantityAddresses, IsComment);
			
		Else
			
			CraftedItems.Delete(ItemIndex);
			
		EndIf;
		
		AddAttributeToDescription(Form, CIRow, IsNewCIKind);
		
		PreviousKind = CIRow.Kind;
		
	EndDo;
	
	If Not DeferredInitialization AND Form.ContactInformationParameters.AddedItemsList.Count() > 0 Then
		
		CommandGroup = VarGroup("GroupContactInformationAddFieldInput",
		Form, Parent, ChildFormItemsGroup.Horizontal, 5);
		CommandGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		
		CommandName = "ContactInformationAddInputField";
		Command = Form.Commands.Add(CommandName);
		Command.ToolTip = NStr("en='Add additional field of the contact information';ru='Добавить дополнительное поле контактной информации'");
		Command.Representation = ButtonRepresentation.PictureAndText;
		Command.Picture = PictureLib.AddListItem;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		
		AddItemDescription(Form, CommandName, 9, True);
		
		Button = Form.Items.Add(CommandName,Type("FormButton"), CommandGroup);
		Button.Title = NStr("en='Add';ru='Добавить'");
		Button.CommandName = CommandName;
		AddItemDescription(Form, CommandName, 2);
		
	EndIf;
	
EndProcedure

// Handler for the OnReadAtServer form event.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form  - ManagedForm - Object-owner form designed to output contact information.
//    Object - Arbitrary - Object-owner of contact information.
//
Procedure OnReadAtServer(Form, Object) Export
	
	FormAttributesList = Form.GetAttributes();
	
	FirstLaunch = True;
	For Each Attribute In FormAttributesList Do
		If Attribute.Name = "ContactInformationParameters" AND TypeOf(Form.ContactInformationParameters) = Type("Structure") Then
			FirstLaunch = False;
			Break;
		EndIf;
	EndDo;
	
	If FirstLaunch Then
		Return;
	EndIf;
	
	Parameters = Form.ContactInformationParameters;
	
	TitleLocationCI = Parameters.TitleLocation;
	TitleLocationCI = ?(ValueIsFilled(TitleLocationCI), FormItemTitleLocation[TitleLocationCI], FormItemTitleLocation.Top);
	
	ItemNameForPlacement = Parameters.GroupForPosting;
	
	ExecutedDeferredInitialization = Parameters.ExecutedDeferredInitialization;
	
	DeleteCommandsAndFormItems(Form);
	
	ArrayOfDeletedDetails = New Array;
	
	ObjectName = Object.Ref.Metadata().Name;
	
	StaticAttributes = CommonUseClientServer.CopyArray(Parameters.ExcludedKinds);
	
	DeferredInitialization = Parameters.DeferredInitialization AND Not ExecutedDeferredInitialization;
	
	For Each FormAttribute In Form.ContactInformationAdditionalAttributeInfo Do
		
		If FormAttribute.ThisAttributeOfTabularSection Then
			
			ArrayOfDeletedDetails.Add("Object." + TabularSectionNameByCI(FormAttribute.Type, ObjectName) + "." + FormAttribute.AttributeName);
			ArrayOfDeletedDetails.Add("Object." + TabularSectionNameByCI(FormAttribute.Type, ObjectName) + "." + FormAttribute.AttributeName + "FieldsValues");
			
		Else
			
			IndexOf = StaticAttributes.Find(FormAttribute.Type);
			
			If IndexOf = Undefined Then // Attribute is created dynamically
				If Not DeferredInitialization Then
					ArrayOfDeletedDetails.Add(FormAttribute.AttributeName);
				EndIf;
			Else
				StaticAttributes.Delete(IndexOf);
			EndIf;
			
		EndIf;
	EndDo;
	
	Form.ContactInformationAdditionalAttributeInfo.Clear();
	Form.ChangeAttributes(, ArrayOfDeletedDetails);
	
	OnCreateAtServer(Form, Object, ItemNameForPlacement, TitleLocationCI, Parameters.ExcludedKinds, DeferredInitialization);
	Parameters.ExecutedDeferredInitialization = ExecutedDeferredInitialization;
	
EndProcedure

// Handler for the AfterWriteOnServer form event.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form  - ManagedForm - Object-owner form designed to output contact information.
//    Object - Arbitrary - Object-owner of contact information.
//
Procedure AfterWriteAtServer(Form, Object) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		If TableRow.ThisAttributeOfTabularSection Then
			
			InformationKind = TableRow.Type;
			AttributeName = TableRow.AttributeName;
			TabularSectionName = TabularSectionNameByCI(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each RowOfTabularSectionForms In FormTabularSection Do
				
				Filter = New Structure;
				Filter.Insert("Kind", InformationKind);
				Filter.Insert("RowIdTableParts", RowOfTabularSectionForms.RowIdTableParts);
				FoundStrings = Object.ContactInformation.FindRows(Filter);
				
				If FoundStrings.Count() = 1 Then
					
					CIRow = FoundStrings[0];
					RowOfTabularSectionForms[AttributeName] = CIRow.Presentation;
					RowOfTabularSectionForms[AttributeName + "FieldsValues"] = CIRow.FieldsValues;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler for the FillCheckProcessingAtServer form event.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form  - ManagedForm - Object-owner form designed to output contact information.
//    Object - Arbitrary - Object-owner of contact information.
//
Procedure FillCheckProcessingAtServer(Form, Object, Cancel) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	LevelErrors = 0;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		Comment   = TableRow.Comment;
		AttributeName  = TableRow.AttributeName;
		
		RequiredFilling = InformationKind.RequiredFilling;
		
		If TableRow.ThisAttributeOfTabularSection Then
			
			TabularSectionName = TabularSectionNameByCI(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each RowOfTabularSectionForms In FormTabularSection Do
				
				Presentation = RowOfTabularSectionForms[AttributeName];
				Field = "Object." + TabularSectionName + "[" + (RowOfTabularSectionForms.LineNumber - 1) + "]." + AttributeName;
				
				If RequiredFilling AND IsBlankString(Presentation) Then
					
					MessageText = NStr("en='Field ""%1"" is not filled.';ru='Поле ""%1"" не заполнено.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
					CommonUseClientServer.MessageToUser(MessageText,,Field);
					CurrentLevelErrors = 2;
					
				Else
					
					FieldsValues = RowOfTabularSectionForms[AttributeName + "FieldsValues"];
					
					CurrentLevelErrors = ValidateContactInformation(Presentation, FieldsValues, InformationKind,
					InformationType, AttributeName, , Field);
					
					RowOfTabularSectionForms[AttributeName] = Presentation;
					RowOfTabularSectionForms[AttributeName + "FieldsValues"] = FieldsValues;
					
				EndIf;
				
				LevelErrors = ?(CurrentLevelErrors > LevelErrors, CurrentLevelErrors, LevelErrors);
				
			EndDo;
			
		Else
			
			FormItem = Form.Items.Find(AttributeName);
			If FormItem = Undefined Then
				Continue; // Item was not created. Deferred initialization was not called.
			EndIf;
			
			Presentation = Form[AttributeName];
			
			If InformationKind <> PreviousKind AND RequiredFilling AND IsBlankString(Presentation) 
				// And there are no other strings with data for CI with multiple values.
				AND Not HasOtherFilledThisKingCIRows(Form, TableRow, InformationKind)
			Then
				
				MessageText = NStr("en='Field ""%1"" is not filled.';ru='Поле ""%1"" не заполнено.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
				CommonUseClientServer.MessageToUser(MessageText,,,AttributeName);
				CurrentLevelErrors = 2;
				
			Else
				
				CurrentLevelErrors = ValidateContactInformation(Presentation, TableRow.FieldsValues,
				InformationKind, InformationType, AttributeName, Comment);
				
			EndIf;
			
			LevelErrors = ?(CurrentLevelErrors > LevelErrors, CurrentLevelErrors, LevelErrors);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
	If LevelErrors <> 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Handler for the BeforeWriteOnServer form event.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form  - ManagedForm - Object-owner form designed to output contact information.
//    Object - Arbitrary - Object-owner of contact information.
//
Procedure BeforeWriteAtServer(Form, Object, Cancel = False) Export
	
	Object.ContactInformation.Clear();
	ObjectName = Object.Ref.Metadata().Name;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		AttributeName  = TableRow.AttributeName;
		RequiredFilling = InformationKind.RequiredFilling;
		
		If TableRow.ThisAttributeOfTabularSection Then
			
			TabularSectionName = TabularSectionNameByCI(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			For Each RowOfTabularSectionForms In FormTabularSection Do
				
				RowID = RowOfTabularSectionForms.GetID();
				RowOfTabularSectionForms.RowIdTableParts = RowID;
				
				TabularSectionRow = Object[TabularSectionName][RowOfTabularSectionForms.LineNumber - 1];
				TabularSectionRow.RowIdTableParts = RowID;
				
				FieldsValues = RowOfTabularSectionForms[AttributeName + "FieldsValues"];
				
				WriteContactInformation(Object, FieldsValues, InformationKind, InformationType, RowID);
				
			EndDo;
			
		Else
			
			WriteContactInformation(Object, TableRow.FieldsValues, InformationKind, InformationType);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
EndProcedure

// Adds (deletes) input filed or comment to form while updating data.
// Called from the CI object-owner form module while implementing subsystem.
//
// Parameters:
//    Form     - ManagedForm - Object-owner form designed to output contact information.
//    Object    - Arbitrary - Object-owner of contact information.
//    Result - Arbitrary - Optional service attribute received from a previous event handler.
//
// Returns:
//    Undefined
//
Function RefreshContactInformation(Form, Object, Result = Undefined) Export
	
	If Result = Undefined Then
		Return Undefined;
		
	ElsIf Result.Property("IsAddingComment") Then
		ChangeComment(Form, Result.AttributeName, Result.IsAddingComment);
		
	ElsIf Result.Property("AddedKind") Then
		AddLineContactInformation(Form, Result);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Handler of the "FillingDataProcessor" event subscription.
//
Procedure FillingContactInformation(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFillingDataProcessor(Source, FillingData);
	
EndProcedure

// Handler of the "FillingDataProcessor" event subscription for documents.
//
Procedure DocumentContactInformationFillingDataProcessor(Source, FillingData, StandardProcessing) Export
	
	ObjectContactInformationFillingDataProcessor(Source, FillingData);
	
EndProcedure

// Executes deferred initialization of attributes and contact information items
//
// Parameters:
//    Form                - ManagedForm - Object-owner form is designed to output contact.
//                           Information.
//    Object               - Arbitrary - Object-owner of contact information.
//
Procedure ExecuteDeferredInitialization(Form, Object) Export
	
	ContactInformationAdditionalAttributeInfo = Form.ContactInformationAdditionalAttributeInfo.Unload(, "Kind, Presentation, FieldsValues, Comment");
	Form.ContactInformationAdditionalAttributeInfo.Clear();
	ItemNameForPlacement = Form.ContactInformationParameters.GroupForPosting;
	TitleLocationCI = Form.ContactInformationParameters.TitleLocation;
	TitleLocationCI = ?(ValueIsFilled(TitleLocationCI), FormItemTitleLocation[TitleLocationCI], FormItemTitleLocation.Top);
	OnCreateAtServer(Form, Object, ItemNameForPlacement, TitleLocationCI, Form.ContactInformationParameters.ExcludedKinds);
	
	For Each ContactInformationKind In Form.ContactInformationParameters.ExcludedKinds Do
		
		Filter = New Structure("Kind", ContactInformationKind);
		RowArray = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
		
		If RowArray.Count() > 0 Then
			SavedValue = ContactInformationAdditionalAttributeInfo.FindRows(Filter)[0];
			CurrentValue = RowArray[0];
			FillPropertyValues(CurrentValue, SavedValue);
			Form[CurrentValue.AttributeName] = SavedValue.Presentation;
		EndIf;
		
	EndDo;
	
	If Form.Items.Find("EmptyDecorationContactInformation") <> Undefined
		AND Form.Items.FieldsGroupEnteringContactInformation.ChildItems.Count() > 0 Then
		Form.Items.EmptyDecorationContactInformation.Visible = False;
	EndIf;
	
	Form.ContactInformationParameters.ExecutedDeferredInitialization = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Reading contact information with other subsystems.

// Checks whether address corresponds to the address information requirements.
//
// Parameters:
//   AddressInXML					 - String -  XML row of a contact information.
//   CheckParameters	 - Structure, CatalogRef.ContactInformationTypes - check box of address check.
//          AddressRussianOnly - Boolean - Address should be only Russian. By default is TRUE.
//          AddressFormat - String - By which classifier to check "KLADR" or "FIAS". By default is "KLADR".
// Returns:
//   Structure - contains structure with fields:
//        * Result - String - Result Checks: "Correct", "NotChecked", "ContainsErrors".
//        * ErrorList - ValueList - Error information.
Function ValidateAddress(Val AddressInXML, CheckParameters = Undefined) Export
	
	Return ContactInformationManagementService.CheckAddressInXML(AddressInXML, CheckParameters);
EndFunction

// It converts all incoming formats of contact information into XML.
//
// Parameters:
//    FieldsValues - String, Structure, Map, ValuesList - contact information fields description.
//    Presentation - String  - presentation. Used if it is impossible to determine presentation from parameter.
//                    FieldsValues (there is no "Presentation" field).
//    ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes - 
//                    Used to determine the type if it is impossible to find it by the FieldsValues field.
//
// Returns:
//     String  - contact information XML data.
//
Function XMLContactInformation(Val FieldsValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	Result = ContactInformationManagementService.CastContactInformationXML(New Structure(
		"FieldsValues, Presentation, ContactInformationKind",
		FieldsValues, Presentation, ExpectedKind));
	Return Result.DataXML;
	
EndFunction

// Returns the corresponding ContactInformationTypes enumeration value by the XML row.
//
// Parameters:
//    XMLString - String - contact information.
//
// Returns:
//    EnumRef.ContactInformationTypes - corresponding type.
//
Function ContactInformationType(Val XMLString) Export
	Return ContactInformationManagementService.ContactInformationType(XMLString);
EndFunction

// It parses  contact information presentation and returns XML string.
// For mailing addresses correct parsing is not guaranteed.
//
//  Parameters:
//      Presentation - String  - row contact information presentation displayed to a user.
//      ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure
//
// Returns:
//      String - contact information in XML.
//
Function PresentationXMLContactInformation(Presentation, ExpectedKind) Export
	
	Return ContactInformationManagementService.ContactInformationXDTOVXML(
		ContactInformationManagementService.XDTOContactInformationByPresentation(Presentation, ExpectedKind));
		
EndFunction

// Receives contact information presentation (address, phone, e-email etc.).
//
// Parameters:
//    XMLString               - XDTOObject, Row - object or contact information XML.
//    ContactInformationKind - Structure - additional parameters of forming presentation for addresses:
//      * IncludeCountriesToPresentation - Boolean - address country will be included to the presentation;
//      * AddressFormat                 - String - If ADDRCLASS is specified, then district
// and urban district are not included in the addresses presentation.
//
// Returns:
//    String - contact information presentation.
//
Function PresentationContactInformation(Val XMLString, Val ContactInformationKind = Undefined) Export
	
	Return ContactInformationManagementService.PresentationContactInformation(XMLString, ContactInformationKind);
	
EndFunction

// Receives comment for contact information.
//
// Parameters:
//   XMLString - XDTOObject, Row - object or contact information XML.
//
// Returns:
//   String
//
Function ContactInformationComment(XMLString) Export
	
	IsRow = TypeOf(XMLString) = Type("String");
	If IsRow AND Not ContactInformationManagementClientServer.IsContactInformationInXML(XMLString) Then
		// Previous field values format, no comment.
		Return "";
	EndIf;
	
	XDTODataObject = ?(IsRow, ContactInformationManagementService.ContactInformationFromXML(XMLString), XMLString);
	Return XDTODataObject.Comment;
	
EndFunction

// Receives comment for contact information.
//
// Parameters:
//   XMLString   - XDTOObject, Row - object or contact information XML. 
//   Comment - String - comment new value.
//
//
Procedure SetContactInformationComment(XMLString, Val Comment) Export
	
	IsRow = TypeOf(XMLString) = Type("String");
	If IsRow AND Not ContactInformationManagementClientServer.IsContactInformationInXML(XMLString) Then
		// Previous field values format, no comment.
		Return;
	EndIf;
	
	XDTODataObject = ?(IsRow, ContactInformationManagementService.ContactInformationFromXML(XMLString), XMLString);
	XDTODataObject.Comment = Comment;
	If IsRow Then
		XMLString = ContactInformationManagementService.ContactInformationXDTOVXML(XDTODataObject);
	EndIf;
	
EndProcedure

// Returns information about the address country.
// If the passed string contains no information about address, an exception will be thrown.
//
// Parameters:
//    XMLString - String - Contact information XML.
//
// Returns:
//    Structure - address country description. Contains fields:
//        * Ref             - CatalogRef.WorldCountries, Undefined - world country corresponding item.
//        * Description       - String - country description part.
//        * Code                - String - country description part.
//        * DescriptionFull - String - country description part.
//        * CodeAlpha2          - String - country description part.
//        * CodeAlpha3          - String - country description part.
//
// If an empty string is passed, an empty string is returned.
// If country is not found in catalog but found in the classifier, then the "Ref" field of the result is not filled in.
// If country is not found both in address and the classifier, then only the "Name" field will be filled in.
//
Function CountryAddressesContactInformation(Val XMLString) Export
	
	Result = New Structure("Ref, Code, Description, DescriptionFull, AlphaCode2, AlphaCode3");
	If IsBlankString(XMLString) Then
		Return Result;
	EndIf;
	
	// Read country name
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(TargetNamespace, "Address") Then
		Raise NStr("en='Impossible to define the country, address is awaited.';ru='Невозможно определить страну, ожидается адрес.'");
	EndIf;
	
	Result.Description = TrimAll(Address.Country);
	CountryInformation = Catalogs.WorldCountries.WorldCountriesData(, Result.Description);
	Return ?(CountryInformation = Undefined, Result, CountryInformation);
EndFunction

// Returns RF territorial entity name for address or an empty string if territorial entity is not defined.
// If the passed string contains no information about address, an exception will be thrown.
//
// Parameters:
//    XMLString - String - Contact information XML.
//
// Returns:
//    String - Description
//
Function AddressesStateContactInformation(Val XMLString) Export
	
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(TargetNamespace, "Address") Then
		Raise NStr("en='Impossible to delete the RF subject, waiting for address.';ru='Невозможно определить субъекта РФ, ожидается адрес.'");
	EndIf;
	
	AddressRF = ContactInformationManagementService.RussianAddress(Address);
	Return ?(AddressRF = Undefined, "", TrimAll(AddressRF.RFTerritorialEntity));
	
EndFunction

// Returns city name for RF address or an empty string for a foreign address.
// If the passed string contains no information about address, an exception will be thrown.
//
// Parameters:
//    XMLString - String - Contact information XML.
//
// Returns:
//    String - Description
//
Function CityAddressContactInformation(Val XMLString) Export
	
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(TargetNamespace, "Address") Then
		Raise NStr("en='Impossible to define the city, address is awaited.';ru='Невозможно определить город, ожидается адрес.'");
	EndIf;
	
	AddressRF = ContactInformationManagementService.RussianAddress(Address);
	Return ?(AddressRF = Undefined, "", TrimAll(AddressRF.City));
	
EndFunction

// Returns a domain of the network address for a web link or an email address.
//
// Parameters:
//    XMLString - String - Contact information XML.
//
// Returns:
//    String - required value.
//
Function DomainAddressContactInformation(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(TargetNamespace, "WebSite") Then
			DomainAddresses = TrimAll(Content.Value);
			Position = Find(DomainAddresses, "://");
			If Position > 0 Then
				DomainAddresses = Mid(DomainAddresses, Position + 3);
			EndIf;
			Position = Find(DomainAddresses, "/");
			Return ?(Position = 0, DomainAddresses, Left(DomainAddresses, Position - 1));
			
		ElsIf Type = XDTOFactory.Type(TargetNamespace, "Email") Then
			DomainAddresses = TrimAll(Content.Value);
			Position = Find(DomainAddresses, "@");
			Return ?(Position = 0, DomainAddresses, Mid(DomainAddresses, Position + 1));
			
		EndIf;
	EndIf;
	
	Raise NStr("en='Impossible to determine the domain, waiting for email or web link';ru='Невозможно определить домен, ожидается электронная почта или веб-ссылка.'");	
EndFunction

// Returns a string with the phone number without a code and additional number.
//
// Parameters:
//    XMLString - String - Contact information XML.
//
// Returns:
//    String - required value.
//
Function PhoneNumberContactInformation(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
			Return TrimAll(Content.Number);
			
		ElsIf Type = XDTOFactory.Type(TargetNamespace, "FaxNumber") Then
			Return TrimAll(Content.Number);
			
		EndIf;
	EndIf;
	
	Raise NStr("en='Impossible to define the number, phone or fax is awaited.';ru='Невозможно определить номер, ожидается телефона или факс.'");
EndFunction

// Compares two references of contact information.
//
// Parameters:
//    Data1 - XDTOObject - object with a contact information.
//            - String     - contact information in the XML format
//            - Structure  - description contact information. Fields are expected:
//                 * FieldValues - String, Structure, ValuesList, Map - contact information fields.
//                 * Presentation - String - Presentation. It is used if you are
// unable to compute presentation from FieldValues (the Presentation field is absent in them).
//                 * Comment - String - comment. It is used in case it was
//                                          impossible to compute a comment from FieldValues
//                 * ContactInformationKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//                                             Structure It is used in case you did not manage to compute type from FieldValues.
//    Data2 - XDTOObject, String, Structure - similarly Data1.
//
// Returns:
//     ValuesTable: - table of different fields with the following columns:
//        * Path      - String - XPath identifying a distinguished value. The
//                               ContactInformationType value means that the sent instances of the contact information have different types.
//        *Description  - String - description of the different attributes in terms of the subject area.
//        * Value1 - String - value corresponding to the object passed in the Data1 parameter.
//        * Value2 - String - value corresponding to the object passed in the Data2 parameters.
//
Function DifferentContactInformation(Val Data1, Val Data2) Export
	Return ContactInformationManagementService.DifferentContactInformation(Data1, Data2);
EndFunction

// Get value of contact information certain kind in the object.
//
// Parameters:
//     Ref                  - AnyRef - ref to contact information
//                                             object-owner (company, counterparty, partner etc).
//     ContactInformationKind - CatalogRef.ContactInformationTypes - data processor parameters.
//
// Returns:
//     String - value row presentation.
//
Function ObjectContactInformation(Ref, ContactInformationKind) Export
	
	ObjectsArray = New Array;
	ObjectsArray.Add(Ref);
	
	ObjectContactInformation = ContactInformationOfObjects(ObjectsArray,, ContactInformationKind);
	
	If ObjectContactInformation.Count() > 0 Then
		Return ObjectContactInformation[0].Presentation;
	EndIf;
	
	Return "";
	
EndFunction

// Designed to create temporary table with contact information of several objects.
//
// Parameters:
//    TempTablesManager - TempTablesManager - for generating.
//    ObjectsArray - Array - contact information owners, all items should be of the same type.
//    CITypes         - Array - optional, used if all types are not specified.
//    CIKinds         - Array -  optional, used if all kinds are not specified.
//
// The TTContactInformation temporary table with fields is created in manager:
//    * Object        - Ref - CI owner.
//    * Kind           - CatalogRef.ContactInformationTypes
//    * Type           - EnumRef.ContactInformationTypes
//    * FieldValues - String - field values data.
//    * Presentation - String - CI presentation.
//
Procedure CreateContactInformation(TempTablesManager, ObjectsArray, CITypes = Undefined, CIKinds = Undefined) Export
	
	If TypeOf(ObjectsArray) = Type("Array") AND ObjectsArray.Count() > 0 Then
		Ref = ObjectsArray.Get(0);
	Else
		Raise NStr("en='Invalid value for the contact information owners array.';ru='Неверное значение для массива владельцев контактной информации.'");
	EndIf;
	
	Query = New Query("
		|SELECT ALLOWED
		|	ContactInformation.Ref AS Object,
		|	ContactInformation.Kind AS Kind,
		|	ContactInformation.Type AS Type,
		|	ContactInformation.FieldsValues AS FieldsValues,
		|	ContactInformation.Presentation AS Presentation
		|INTO TTContactInformation
		|FROM
		|	" + Ref.Metadata().FullName() + ".ContactInformation
		|AS
		|ContactInformation WHERE ContactInformation.Ref IN (&ObjectsArray)
		|	" + ?(CITypes = Undefined, "", "And ContactInformation.Type IN (&CITypes)") + "
		|	" + ?(CIKinds = Undefined, "", "And ContactInformation.Type IN (&CIKinds)") + "
		|");
	
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("CITypes", CITypes);
	Query.SetParameter("CIKinds", CIKinds);
	
	Query.Execute();
EndProcedure

// Designed to get contact information for several objects.
//
// Parameters:
//    ObjectsArray - Array - contact information owners, all items should be of the same type.
//    CITypes         - Array - optional, used if all types are not specified.
//    CIKinds         - Array -  optional, used if all kinds are not specified.
//
// Return
//    value Values table - result. Columns:
//        * Object        - Ref - CI owner.
//        * Kind           - CatalogRef.ContactInformationTypes
//        * Type           - EnumRef.ContactInformationTypes
//        * FieldValues - String - field values data.
//        * Presentation - String - CI presentation.
//
Function ContactInformationOfObjects(ObjectsArray, CITypes = Undefined, CIKinds = Undefined) Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	CreateContactInformation(Query.TempTablesManager, ObjectsArray, CITypes, CIKinds);
	
	Query.Text =
	"SELECT
	|	ContactInformation.Object AS Object,
	|	ContactInformation.Kind AS Kind,
	|	ContactInformation.Type AS Type,
	|	ContactInformation.FieldsValues AS FieldsValues,
	|	ContactInformation.Presentation AS Presentation
	|FROM
	|	TTContactInformation AS ContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction

// Fills in contact information in objects.
//
// Parameters:
//    FillingData - ValueTable - describes objects for filling. Contains columns:
//        * Receiver    - Arbitrary - ref or object where you should fill in CI.
//        * KindCI       - CatalogRef.ContactInformationTypes  - contact information kind filled
//                                                                     in in the receiver.
//        * StructureCI - ValuesList, String, Structure - contact information fields of values data.
//        * StringKey  - Structure - filter to search for a string in tabular section where Key - column name
//                                    in the tabular section, Value - filter value.
//
Procedure FillContactInformationObjects(FillingData) Export
	
	PreviousReceiver = Undefined;
	FillingData.Sort("Receiver, CIKind");
	
	For Each RowFill In FillingData Do
		
		Receiver = RowFill.Receiver;
		If CommonUse.IsReference(TypeOf(Receiver)) Then
			Receiver = Receiver.GetObject();
		EndIf;
		
		If PreviousReceiver <> Undefined AND PreviousReceiver <> Receiver Then
			If PreviousReceiver.Ref = Receiver.Ref Then
				Receiver = PreviousReceiver;
			Else
				PreviousReceiver.Write();
			EndIf;
		EndIf;
		
		CIKind = RowFill.CIKind;
		ReceiverObjectName = Receiver.Metadata().Name;
		TabularSectionName = TabularSectionNameByCI(CIKind, ReceiverObjectName);
		
		If IsBlankString(TabularSectionName) Then
			FillContactInformationTableParts(Receiver, CIKind, RowFill.CIStructure);
		Else
			If TypeOf(RowFill.RowKey) <> Type("Structure") Then
				Continue;
			EndIf;
			
			If RowFill.RowKey.Property("LineNumber") Then
				LineCountTabularSection = Receiver[TabularSectionName].Count();
				LineNumber = RowFill.RowKey.LineNumber;
				If LineNumber > 0 AND LineNumber <= LineCountTabularSection Then
					TabularSectionRow = Receiver[TabularSectionName][LineNumber - 1];
					FillContactInformationTableParts(Receiver, CIKind, RowFill.CIStructure, TabularSectionRow);
				EndIf;
			Else
				RowsOfTabularSection = Receiver[TabularSectionName].FindRows(RowFill.RowKey);
				For Each TabularSectionRow In RowsOfTabularSection Do
					FillContactInformationTableParts(Receiver, CIKind, RowFill.CIStructure, TabularSectionRow);
				EndDo;
			EndIf;
		EndIf;
		
		PreviousReceiver = Receiver;
		
	EndDo;
	
	If PreviousReceiver <> Undefined Then
		PreviousReceiver.Write();
	EndIf;
	
EndProcedure

// Fills in object contact information.
//
// Parameters:
//    Receiver    - Arbitrary - ref or object where you should fill in CI.
//    CIKind       - CatalogRef.ContactInformationTypes - contact information kind filled in in the receiver.
//    CIStructure - Structure - contact information filled structure.
//    RowKey  - Structure  - selection to search for a string in tabular section, Key - Column name in
//                               the tabular section, value - filter value.
//
Procedure FillContactInformationObject(Receiver, CIKind, CIStructure, RowKey = Undefined) Export
	
	FillingData = New ValueTable;
	FillingData.Columns.Add("Receiver");
	FillingData.Columns.Add("CIKind");
	FillingData.Columns.Add("CIStructure");
	FillingData.Columns.Add("RowKey");
	
	RowFill = FillingData.Add();
	RowFill.Receiver = Receiver;
	RowFill.CIKind = CIKind;
	RowFill.CIStructure = CIStructure;
	RowFill.RowKey = RowKey;
	
	FillContactInformationObjects(FillingData);
	
EndProcedure

// Outdated. You should use ObjectContactInformation.
//
Function GetObjectContactInformation(Ref, ContactInformationKind) Export
	Return ObjectContactInformation(Ref, ContactInformationKind);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Backward compatibility.

//  Returns all contact information values of a definite kind for object-owner.
//
//  Parameters:
//      Ref                  - AnyRef - ref to contact information
//                                              object-owner (company, counterparty, partner etc).
//      ContactInformationKind - CatalogRef.ContactInformationTypes - data processor parameters.
//
//  Returns:
//      Values table - information. Columns: 
//          * LineNumber     - Number     - row number of the object-owner additional tabular section.
//          * Presentation   - String    - CI presentation entered by a user.
//          * FieldsStructure  - Structure - information data key-value pairs.
//
Function ObjectContactInformationTable(Ref, ContactInformationKind) Export
	
	Query = New Query(StringFunctionsClientServer.SubstituteParametersInString("
		|SELECT 
		|	Data.RowIdTableParts AS LineNumber,
		|	Data.Presentation                     AS Presentation,
		|	Data.FieldsValues                     AS FieldsValues
		|FROM
		|	%1.ContactInformation AS Data
		|WHERE
		|	Data.Ref = &Ref
		|	AND Data.Kind = &Kind
		|ORDER BY
		|	Data.RowIdTableParts
		|", Ref.Metadata().FullName()));
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Kind", ContactInformationKind);
	
	Result = New ValueTable;
	Result.Columns.Add("LineNumber");
	Result.Columns.Add("Presentation");
	Result.Columns.Add("FieldsStructure");
	Result.Indexes.Add("LineNumber");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DataRow = Result.Add();
		FillPropertyValues(DataRow, Selection, "LineNumber, Presentation");
		DataRow.FieldsStructure = PreviousStructureOfContactInformationXML(
			Selection.FieldsValues, ContactInformationKind);
	EndDo;
	
	Return  Result;
EndFunction


// Converts XML format data to the previous format of contact information.
//
// Parameters:
//    Data                 - String - Contact information XML.
//    AbridgedFieldsContent - Boolean - if False, then fields will be excluded
//                                      from the fields content that are absent in SSL versions less than 2.1.3.
//
// Returns:
//    String  - key-value pairs set separated by a line break.
//
Function PreviousFormatContactInformationXML(Val Data, Val AbridgedFieldsContent = False) Export
	
	If ContactInformationManagementClientServer.IsContactInformationInXML(Data) Then
		OldFormat = ContactInformationManagementService.ContactInformationInOldStructure(Data, AbridgedFieldsContent);
		Return ContactInformationManagementClientServer.ConvertFieldListToString(
			OldFormat.FieldsValues, False);
	EndIf;
	
	Return Data;
EndFunction

// Converts XML new format data of contact information to the old format structure.
//
// Parameters:
//   Data                  - String - XML of contact information or key-value pair.
//   ContactInformationKind - CatalogRef.ContactInformationTypes, Structure - contact information parameters. 
//
// Returns:
//   Structure - key-value pairs set. Properties content for address:
//        ** Country           - String - text presentation of a country.
//        ** CountryCode        - String - country code by OKSM.
//        ** Index           - String - postal code (only for RF addresses).
//        ** State           - String - text presentation of the RF territorial entity (only for RF addresses).
//        ** StateCode       - String - RF territorial entity code (only for RF addresses).
//        ** StateAbbr - String - abbr region (if FieldsOldContent = False).
//        ** Region            - String - text presentation of a region (only for RF addresses).
//        ** RegionAbbr  - String - abbr district (if FieldsOldContent = False).
//        ** City            - String - text presentation of a city (only for RF addresses).
//        ** CityAbbreviation  - String - city abbreviation (only for RF addresses).
//        ** Settlement  - String - text presentation of the locality (only for RF addresses).
//        ** SettlementAbbreviation - String - abbr inhabited locality (if FieldsOldContent = False).
//        ** Street            - String - street text presentation (only for RF addresses).
//        ** StreetAbbreviation  - String - abbr streets (if FieldsOldContent = False).
//        ** HouseType          - String - cm. TypesOfAddressingAddressesRF().
//        ** House              - String - text presentation of a house (only for RF addresses).
//        ** HouseType       - String - cm. TypesOfAddressingAddressesRF().
//        ** Block           - String - text presentation of a block (only for RF addresses).
//        ** ApartmentType      - String - cm. TypesOfAddressingAddressesRF().
//        ** Apartment         - String - text presentation of an apartment (only for RF addresses).
//       Properties content for phone:
//        ** CountryCode        - String - code Countries. ForExample, +7.
//        ** CityCode        - String - city code. For example, 495.
//        ** PhoneNumber    - String - phone number.
//        ** Supplementary       - String - additional phone number.
//
Function PreviousStructureOfContactInformationXML(Val Data, Val ContactInformationKind = Undefined) Export
	
	If ContactInformationManagementClientServer.IsContactInformationInXML(Data) Then
		// CI new format
		Return ContactInformationManagementClientServer.FieldValuesStructure(
			PreviousFormatContactInformationXML(Data));
		
	ElsIf IsBlankString(Data) AND ContactInformationKind <> Undefined Then
		// Generate by kind
		Return ContactInformationManagementClientServer.StructureContactInformationByType(
			ContactInformationKind.Type);
		
	EndIf;
	
	// Return full string for this kind with the filled in fields.
	Return ContactInformationManagementClientServer.FieldValuesStructure(Data, ContactInformationKind);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

// Determines country data by the countries list or by OKSM classifier.
//
// Parameters:
//    CountryCode    - String, Number - OKSM country code. If it is not specified, then search by code is not executed.
//    Description - String - Country name. If it is not specified, then search by name is not executed.
//
// Returns:
//    Structure - country description. Contains fields:
//        * Ref             - CatalogRef.WorldCountries, Undefined - world country corresponding item.
//        * Description       - String - country description part.
//        * Code                - String - country description part.
//        * DescriptionFull - String - country description part.
//        * CodeAlpha2          - String - country description part.
//        * CodeAlpha3          - String - country description part.
//    Undefined - country is not found both in the address and the classifier.
//
Function WorldCountriesData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Return Catalogs.WorldCountries.WorldCountriesData(CountryCode, Description);
EndFunction

// Specifies country data by OKSM classifier.
//
// Parameters:
//    CountryCode - String, Number - country code.
//
// Returns:
//    Structure - country description. Contains fields:
//        * Description       - String - country description part.
//        * Code                - String - country description part.
//        * DescriptionFull - String - country description part.
//        * CodeAlpha2          - String - country description part.
//        * CodeAlpha3          - String - country description part.
//    Undefined - country is not found in the classifier.
//
Function ClassifierDataOfWorldCountriesByCode(Val CountryCode) Export
	Return Catalogs.WorldCountries.ClassifierDataOfWorldCountriesByCode(CountryCode);
EndFunction

// Specifies country data by OKSM classifier.
//
// Parameters:
//    Description - String - country name.
//
// Returns:
//    Structure - country description. Contains fields:
//        * Description       - String - country description part.
//        * Code                - String - country description part.
//        * DescriptionFull - String - country description part.
//        * CodeAlpha2          - String - country description part.
//        * CodeAlpha3          - String - country description part.
//    Undefined - country is not found in the classifier.
//
Function WorldCountriesClassifierDataByName(Val Description) Export
	Return Catalogs.WorldCountries.WorldCountriesClassifierDataByName(Description);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Receive values of the contact information definite type in the object.
//
// Parameters
//    Ref                  - AnyRef - ref to object-owner of contact information (company, counterparty,
//    partner etc) ContactInformationType - EnumRef.ContactInformationTypes
//
// Returns:
//    ValueTable - columns 
//        * Value - string - value row
//        presentation * Kind      - string - contact information kind presentation
//
Function ObjectContactInformationValues(Ref, ContactInformationType) Export
	
	ObjectsArray = New Array;
	ObjectsArray.Add(Ref);
	
	ObjectContactInformation = ContactInformationOfObjects(ObjectsArray, ContactInformationType);
	
	Query = New Query;
	
	Query.SetParameter("ObjectContactInformation", ObjectContactInformation);
	
	Query.Text =
	"SELECT
	|	ObjectContactInformation.Presentation,
	|	ObjectContactInformation.Kind
	|INTO TTContactInformationObject
	|FROM
	|	&ObjectContactInformation AS ObjectContactInformation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectContactInformation.Presentation AS Value,
	|	PRESENTATION(ObjectContactInformation.Kind) AS Kind
	|FROM
	|	TTContactInformationObject AS ObjectContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction


// Sets contact information kind properties.
// 
// Parameters:
//    Parameters - Structure - See description in the ContactInformationKindParameters function
// 
Procedure SetPropertiesContactInformationKind(Parameters) Export
	
	If TypeOf(Parameters.Kind) = Type("String") Then
		Object = Catalogs.ContactInformationTypes[Parameters.Kind].GetObject();
	Else
		Object = Parameters.Kind.GetObject();
	EndIf;
	
	Object.Type                                  = Parameters.Type;
	Object.ToolTip                            = Parameters.ToolTip;
	Object.EditMethodEditable    = Parameters.EditMethodEditable;
	Object.EditInDialogOnly         = Parameters.EditInDialogOnly;
	Object.RequiredFilling               = Parameters.RequiredFilling;
	Object.AllowInputOfMultipleValues      = Parameters.AllowInputOfMultipleValues;
	Object.DisableEditByUser = Parameters.DisableEditByUser;
	
	VerificationSettings = Parameters.VerificationSettings;
	CheckSettings = TypeOf(VerificationSettings) = Type("Structure");
	ParametersError   = NStr("en='Address verification settings are filled incorrectly';ru='Некорректно заполнены настройки проверки адреса'");
	
	If CheckSettings AND Parameters.Type = Enums.ContactInformationTypes.Address Then
		If VerificationSettings.AddressRussianOnly Then
			If Not VerificationSettings.CheckCorrectness Then
				If VerificationSettings.ProhibitEntryOfIncorrect Then
					Raise ParametersError;
				EndIf;
			Else
				// See note
				If Not VerificationSettings.ProhibitEntryOfIncorrect Then
					Raise ParametersError;
				EndIf;
			EndIf;
			
		Else
			If VerificationSettings.CheckCorrectness Or VerificationSettings.ProhibitEntryOfIncorrect Or VerificationSettings.HideObsoleteAddresses Then
				Raise ParametersError;
			EndIf;
			
		EndIf;
		
		FillPropertyValues(Object, VerificationSettings);
		
	ElsIf CheckSettings AND Parameters.Type = Enums.ContactInformationTypes.EmailAddress Then
		If Not VerificationSettings.CheckCorrectness Then
			If VerificationSettings.ProhibitEntryOfIncorrect Then
				Raise ParametersError;
			EndIf;
		Else
			// See note
			If Not VerificationSettings.ProhibitEntryOfIncorrect Then
				Raise ParametersError;
			EndIf;
		EndIf;
		SetCheckAttributesValue(Object, VerificationSettings);
		
	Else
		SetCheckAttributesValue(Object);
		
	EndIf;
	
	If Parameters.Order <> Undefined Then
		Object.AdditionalOrderingAttribute = Parameters.Order;
	EndIf;
	
	InfobaseUpdate.WriteData(Object);
	
EndProcedure

// Returns parameters structure of contact information kind for a definite type
// 
// Parameters:
//    Type - EnumRef.ContactInformationTypes, String - contact information type
//                                                                for the CheckSettings property filling
// 
// Returns:
//    Structure - contains structure with fields:
//        * Kind - CatalogRef.ContactInformationTypes, String   - Ref to the contact
//                                                                      information kind or the predefined item ID.
//        * Type - EnumRef.ContactInformationTypes - Contact information type
//                                                                      or its identifier.
//        * Tooltip - String                                        - Tooltip to the contact information kind.
//        * Order - Number, Undefined                             - Contact information kind order,
//                                                                      position in list relatively to the other items:
//                                                                          Undefined - not reassign;
//                                                                          0            - assign automatically;
//                                                                          Number > 0    - assign specified order.
//        * CanChangeEditingMethod - Boolean                - True if there is an
//                                                                      opportunity to change editing method only in the dialog, False - else.
//        * EditOnlyInDialog - Boolean                     - True if you edit only
//                                                                      in the dialog, False - else.
//        * RequiredFilling                                    - Boolean - True if mandatory
//                                                                      field filling is required, False - else.
//        * AllowSeveralValuesOutput - Boolean                  - Shows that it
//                                                                      is possible to use additional input fields for the specified kind.
//        * DisableEditByUser - Boolean             - Shows that
//                                                                      user editing of contact
//                                                                      information kind property is unavailable.
//        * CheckSettings - Structure, Undefined               - Settings of the contact information kind check.
//            For the Address type - Structure containing fields:
//                * AddressRussianOnly        - Boolean - True if only Russian addresses are used, False -
//                                                          else.
//                * CheckCorrectness        - Boolean - True if address is checked by
//                                                          KLADR profiles (Only if AddressRussianOnly = True), False - else.
//                * CheckByFIAS              - Boolean - True if address is checked by
//                                                          FIAS profiles (Only if AddressRussianOnly = True), False - else.
//                * ProhibitEntryIncorrect   - Boolean - True if it is required
//                                                          to prohibit user to write incorrect
//                                                          address (Only if CheckCorrectness = True), False - else.
//                * HideObsoleteAddresses   - Boolean - True if it is not required to
//                                                          show irrelevant addresses while entering
//                                                          (Only if AddressRussianOnly = True), False - else.
//                * IncludeCountriesToPresentation - Boolean - True if it is required to
//                                                          include country name to the address presentation, False - else.
//            For the EmailAddress type - Structure containing fields:
//                * CheckCorrectness        - Boolean - True if it is required to check
//                                                          whether email address is correct, False - else.
//                * ProhibitEntryIncorrect   - Boolean - True if it is required
//                                                          to prohibit user to
//                                                          write incorrect address (Only if CheckCorrectness = True), False - else.
//            For the rest of the types or to specify the default settings Undefined is used.
// 
// Note:
//    To set the CheckCorrectness parameter to the True value, you
//    should set the ProhibitEntryIncorrect parameter to the True value.
// 
//    While using the Order parameter, you should closely monitor the uniqueness of the assigned value. If
//    after the update order values are non unique, then user will
//    not be able to set order.
//    It is generally recommended not to use this parameter (the order does not change)
//    or to fill it in with 0 value (the order will be automatically assigned to the "Items order setting" subsystem while executing the procedure).
//    To put CI kinds in a particular order relative to each other without explicit
//    placement at the top of the list, it is enough to call this procedure
//    in the required sequence for each CI kind with order specification 0. If a definite predefined CI kind is added to the existing ones in
//    IB, it is not recommended to assign order explicitly.
// 
Function ParametersKindContactInformation(Type = Undefined) Export
	
	If TypeOf(Type) = Type("String") Then
		SetType = Enums.ContactInformationTypes[Type];
	Else
		SetType = Type;
	EndIf;
	
	ParametersKind = New Structure;
	ParametersKind.Insert("Kind");
	ParametersKind.Insert("Type", SetType);
	ParametersKind.Insert("ToolTip");
	ParametersKind.Insert("Order");
	ParametersKind.Insert("EditMethodEditable", False);
	ParametersKind.Insert("EditInDialogOnly", False);
	ParametersKind.Insert("RequiredFilling", False);
	ParametersKind.Insert("AllowInputOfMultipleValues", False);
	ParametersKind.Insert("DisableEditByUser", False);
	
	If SetType = Enums.ContactInformationTypes.Address Then
		VerificationSettings = New Structure;
		VerificationSettings.Insert("AddressRussianOnly", False);
		VerificationSettings.Insert("CheckCorrectness", False);
		VerificationSettings.Insert("CheckByFIAS", False);
		VerificationSettings.Insert("ProhibitEntryOfIncorrect", False);
		VerificationSettings.Insert("HideObsoleteAddresses", False);
		VerificationSettings.Insert("IncludeCountryInPresentation", False);
	ElsIf SetType = Enums.ContactInformationTypes.EmailAddress Then
		VerificationSettings = New Structure;
		VerificationSettings.Insert("CheckCorrectness", False);
		VerificationSettings.Insert("ProhibitEntryOfIncorrect", False);
	Else
		VerificationSettings = Undefined;
	EndIf;
	
	ParametersKind.Insert("VerificationSettings", VerificationSettings);
	
	Return ParametersKind;
	
EndFunction

// Writes contact information from XML to the Object contact information tabular section fields.
//
// Parameters:
//    Object - AnyRef - phone or fax number.
//    FieldsValues - String - contact information in the XML format
//    InformationKind - Catalog.ContactInformationTypes - ref to contact information kind.
//    InformationType - Enum.ContactInformationTypes - contact information type.
//    RowID - Number - tabular section string ID.
Procedure WriteContactInformation(Object, FieldsValues, InformationKind, InformationType, RowID = 0) Export
	
	ObjectCI = ContactInformationManagementService.ContactInformationFromXML(FieldsValues, InformationKind);
	
	If Not ContactInformationManagementService.XDTOContactInformationFilled(ObjectCI) Then
		Return;
	EndIf;
	
	NewRow = Object.ContactInformation.Add();
	NewRow.Presentation = ObjectCI.Presentation;
	NewRow.FieldsValues = ContactInformationManagementService.ContactInformationXDTOVXML(ObjectCI);
	NewRow.Kind           = InformationKind;
	NewRow.Type           = InformationType;
	
	If ValueIsFilled(RowID) Then
		NewRow.RowIdTableParts = RowID;
	EndIf;
	
	// Fill in TS additional attributes.
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionForEMailAddressAttributes(NewRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionForAddressAttributes(NewRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionForPhoneAttributes(NewRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionForPhoneAttributes(NewRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionForWebpageAttributes(NewRow, ObjectCI);
		
	EndIf;
	
EndProcedure

// Outdated. You should use SetContactInformationKindProperties.
//
Procedure RefreshContactInformationKind(Kind, Type, ToolTip, EditMethodEditable, EditInDialogOnly,
	RequiredFilling, Order = Undefined, AllowInputOfMultipleValues = False, VerificationSettings = Undefined) Export
	
	ParametersKind = ParametersKindContactInformation();
	ParametersKind.Kind = Kind;
	ParametersKind.Type = Type;
	ParametersKind.ToolTip = ToolTip;
	ParametersKind.EditMethodEditable = EditMethodEditable;
	ParametersKind.EditInDialogOnly = EditInDialogOnly;
	ParametersKind.RequiredFilling = RequiredFilling;
	ParametersKind.Order = Order;
	ParametersKind.AllowInputOfMultipleValues = AllowInputOfMultipleValues;
	ParametersKind.VerificationSettings = VerificationSettings;
	ParametersKind.DisableEditByUser = False;
	
	SetPropertiesContactInformationKind(ParametersKind);
	
EndProcedure

#EndRegion


#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Initialize items on object-owner contact information form.

Procedure AddItemDescription(Form, ItemName, Priority, ThisCommand = False)
	
	Form.ContactInformationParameters.AddedElements.Add(ItemName, Priority, ThisCommand);
	
EndProcedure

Procedure DeleteItemDetails(Form, ItemName)
	
	AddedElements = Form.ContactInformationParameters.AddedElements;
	FoundString = AddedElements.FindByValue(ItemName);
	AddedElements.Delete(FoundString);
	
EndProcedure

Function TitleLeft(Form, Val TitleLocationCI = Undefined)
	
	If Not ValueIsFilled(TitleLocationCI) Then
		
		SavedTitleLocation = Form.ContactInformationParameters.TitleLocation;
		If ValueIsFilled(SavedTitleLocation) Then
			TitleLocationCI = FormItemTitleLocation[SavedTitleLocation];
		Else
			TitleLocationCI = FormItemTitleLocation.Top;
		EndIf;
		
	EndIf;
	
	Return (TitleLocationCI = FormItemTitleLocation.Left);
	
EndFunction

Procedure ChangeComment(Form, AttributeName, IsAddingComment)
	
	DetailsContactInformation = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("AttributeName", AttributeName);
	FoundString = DetailsContactInformation.FindRows(Filter)[0];
	
	// Title and edit box
	ItemTitle = Form.Items.Find("Title" + AttributeName);
	NameComments = "Comment" + AttributeName;
	
	TitleLeft = TitleLeft(Form);
	
	If IsAddingComment Then
		
		InputField = Form.Items.Find(AttributeName);
		GroupInputFields = Form.Items.FieldsGroupEnteringContactInformation;
		
		CurrentItem = ?(GroupInputFields.ChildItems.Find(InputField.Name) = Undefined, InputField.Parent, InputField);
		IndexOfCurrentItem = GroupInputFields.ChildItems.IndexOf(CurrentItem);
		NextItem = GroupInputFields.ChildItems.Get(IndexOfCurrentItem + 1);
		
		Comment = Comment(Form, FoundString.Comment, NameComments, GroupInputFields);
		Form.Items.Move(Comment, GroupInputFields, NextItem);
		
		If TitleLeft Then
			
			TitlesGroup = Form.Items.GroupHeadersContactInformation;
			IndexOfHeader = TitlesGroup.ChildItems.IndexOf(ItemTitle);
			NextTitle = TitlesGroup.ChildItems.Get(IndexOfHeader + 1);
			
			NameStubs = "EndCapHeader" + AttributeName;
			EndCap = Form.Items.Add(NameStubs, Type("FormDecoration"), TitlesGroup);
			Form.Items.Move(EndCap, TitlesGroup, NextTitle);
			AddItemDescription(Form, NameStubs, 2);
			
		EndIf;
		
	Else
		
		Comment = Form.Items[NameComments];
		Form.Items.Delete(Comment);
		DeleteItemDetails(Form, NameComments);
		
		If TitleLeft Then
			
			ItemTitle.Height = 1;
			
			NameStubs = "EndCapHeader" + AttributeName;
			EndCapHeader = Form.Items[NameStubs];
			Form.Items.Delete(EndCapHeader);
			DeleteItemDetails(Form, NameStubs);
			
		EndIf;
		
	EndIf;
	
	// Action
	ActionsGroup = Form.Items.GroupActionsContactInformation;
	NameStubsActions = "EndCapActions" + AttributeName;
	EndCapActions = Form.Items.Find(NameStubsActions);
	
	If IsAddingComment Then
		
		If EndCapActions = Undefined Then
			
			EndCapActions = Form.Items.Add(NameStubsActions, Type("FormDecoration"), ActionsGroup);
			EndCapActions.Height = 1;
			Action = Form.Items["Command" + AttributeName];
			IndexOfCommands = ActionsGroup.ChildItems.IndexOf(Action);
			NextItem = ActionsGroup.ChildItems.Get(IndexOfCommands + 1);
			If EndCapActions <> NextItem Then
				Form.Items.Move(EndCapActions, ActionsGroup, NextItem);
			EndIf;
			AddItemDescription(Form, NameStubsActions, 2);
			
		Else
			
			EndCapActions.Height = 2;
			
		EndIf;
		
	Else
		
		If EndCapActions.Height = 1 Then
			
			Form.Items.Delete(EndCapActions);
			DeleteItemDetails(Form, NameStubsActions);
			
		Else
			
			EndCapActions.Height = 1;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AddLineContactInformation(Form, Result)
	
	AddedKind = Result.AddedKind;
	If TypeOf(AddedKind)= Type("CatalogRef.ContactInformationTypes") Then
		InformationAboutCIKind = CommonUse.ObjectAttributesValues(AddedKind, "Type, Name< EditOnlyInDialog, Tooltip");
	Else
		InformationAboutCIKind = AddedKind;
		AddedKind    = AddedKind.Ref;
	EndIf;
	
	TableContactInformation = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("Kind", AddedKind);
	FoundStrings = TableContactInformation.FindRows(Filter);
	ItemCount = FoundStrings.Count();
	
	LastRow = FoundStrings.Get(ItemCount-1);
	IndexOfRowsToBeAdded = TableContactInformation.IndexOf(LastRow) + 1;
	IsLastRow = False;
	If IndexOfRowsToBeAdded = TableContactInformation.Count() Then
		IsLastRow = True;
	Else
		NextAttributeName = TableContactInformation[IndexOfRowsToBeAdded].AttributeName;
	EndIf;
	
	NewRow = TableContactInformation.Insert(IndexOfRowsToBeAdded);
	AttributeName = "ContactInformationField" + NewRow.GetID();
	NewRow.AttributeName = AttributeName;
	NewRow.Type = AddedKind;
	NewRow.Type = InformationAboutCIKind.Type;
	NewRow.ThisAttributeOfTabularSection = False;
	
	ArrayOfAddedDetails = New Array;
	ArrayOfAddedDetails.Add(New FormAttribute(AttributeName, New TypeDescription("String", , New StringQualifiers(500)), , InformationAboutCIKind.Description, True));
	
	Form.ChangeAttributes(ArrayOfAddedDetails);
	
	TitleLeft = TitleLeft(Form);
	
	// Rendering on form
	If TitleLeft Then
		TitlesGroup = Form.Items.GroupHeadersContactInformation;
		Title = TitleFunc(Form, InformationAboutCIKind.Type, AttributeName, TitlesGroup, InformationAboutCIKind.Description);
		
		If Not IsLastRow Then
			NextTitle = Form.Items["Title" + NextAttributeName];
			Form.Items.Move(Title, TitlesGroup, NextTitle);
		EndIf;
	EndIf;
	
	GroupInputFields = Form.Items.FieldsGroupEnteringContactInformation;
	InputField = InputField(Form, InformationAboutCIKind.EditInDialogOnly, InformationAboutCIKind.Type, AttributeName, InformationAboutCIKind.ToolTip);
	
	If Not IsLastRow Then
		
		NameOfNextItem = LastRow.AttributeName;
		
		If ValueIsFilled(LastRow.Comment) Then
			NameOfNextItem = "Comment" + NameOfNextItem;
		EndIf;
		
		IndexOfNextItem = GroupInputFields.ChildItems.IndexOf(Form.Items[NameOfNextItem]) + 1;
		NextItem = GroupInputFields.ChildItems.Get(IndexOfNextItem);
		
		Form.Items.Move(InputField, GroupInputFields, NextItem);
		
	EndIf;
	
	ActionsGroup = Form.Items.GroupActionsContactInformation;
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	QuantityAddresses = TableContactInformation.FindRows(Filter).Count();
	
	NameActions = "Command" + NextAttributeName;
	NameStubs = "DecorationTop" + NextAttributeName;
	
	If Form.Items.Find(NameStubs) <> Undefined Then
		NameOfNextAction = NameStubs;
	ElsIf Form.Items.Find(NameActions) <> Undefined Then
		NameOfNextAction = NameActions;
	Else
		NameOfNextAction = "EndCapActions" + NextAttributeName;
	EndIf;
	
	Action = Action(Form, InformationAboutCIKind.Type, AttributeName, ActionsGroup, QuantityAddresses);
	If Not IsLastRow Then
		NextAction = Form.Items[NameOfNextAction];
		Form.Items.Move(Action, ActionsGroup, NextAction);
	EndIf;
	
	Form.CurrentItem = Form.Items[AttributeName];
	
	If InformationAboutCIKind.Type = Enums.ContactInformationTypes.Address
		AND InformationAboutCIKind.EditInDialogOnly Then
		
		Result.Insert("AddressesFormItem", AttributeName);
		
	EndIf;
	
EndProcedure

Function TitleFunc(Form, Type, AttributeName, TitlesGroup, Description, IsNewCIKind = False, IsComment = False)
	
	NameHeader = "Title" + AttributeName;
	Item = Form.Items.Add(NameHeader, Type("FormDecoration"), TitlesGroup);
	Item.Title = ?(IsNewCIKind, Description + ":", "");
	
	If Type = Enums.ContactInformationTypes.Another Then
		Item.Height = 5;
		Item.VerticalAlign = ItemVerticalAlign.Top;
	Else
		Item.VerticalAlign = ItemVerticalAlign.Center;
	EndIf;
	
	AddItemDescription(Form, NameHeader, 2);
	
	If IsComment Then
		
		NameStubs = "EndCapHeader" + AttributeName;
		EndCap = Form.Items.Add(NameStubs, Type("FormDecoration"), TitlesGroup);
		AddItemDescription(Form, NameStubs, 2);
		
	EndIf;
	
	Return Item;
	
EndFunction

Function InputField(Form, EditInDialogOnly, Type, AttributeName, ToolTip, IsNewCIKind = False, RequiredFilling = False)
	
	TitleLeft = TitleLeft(Form);
	
	Item = Form.Items.Add(AttributeName, Type("FormField"), Form.Items.FieldsGroupEnteringContactInformation);
	Item.Type = FormFieldType.InputField;
	Item.ToolTip = ToolTip;
	Item.DataPath = AttributeName;
	Item.HorizontalStretch = True;
	Item.TitleLocation = ?(TitleLeft Or Not IsNewCIKind, FormItemTitleLocation.None, FormItemTitleLocation.Top);
	Item.SetAction("Clearing", "Attachable_ContactInformationClearing");
	
	AddItemDescription(Form, AttributeName, 2);
	
	// Set edit box properties.
	If Type = Enums.ContactInformationTypes.Another Then
		Item.Height = 5;
		Item.MultiLine = True;
		Item.VerticalStretch = False;
	Else
		
		// Enter a comment via context menu.
		CommandName = "ContextMenu" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		Button = Form.Items.Add(CommandName,Type("FormButton"), Item.ContextMenu);
		Command.ToolTip = NStr("en='Enter comment';ru='Ввести комментарий'");
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Button.Title = NStr("en='Enter comment';ru='Ввести комментарий'");
		Button.CommandName = CommandName;
		Command.ModifiesStoredData = True;
		
		AddItemDescription(Form, CommandName, 1);
		AddItemDescription(Form, CommandName, 9, True);
	EndIf;
	
	If RequiredFilling AND IsNewCIKind Then
		Item.AutoMarkIncomplete = True;
	EndIf;
	
	// Edit in dialog
	If ForContactInformationTypeAvailableEditInDialog(Type) Then
		
		Item.ChoiceButton = True;
		
		If EditInDialogOnly Then
			Item.TextEdit = False;
			Item.BackColor = StyleColors.ContactInformationWithEditingInDialogColor;
		EndIf;
		Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
		
	EndIf;
	Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	
	Return Item;
	
EndFunction

Function Action(Form, Type, AttributeName, ActionsGroup, QuantityAddresses, IsComment = False)
	
	CanCreateAction = True;
	If Type = Enums.ContactInformationTypes.EmailAddress Then
		If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperations = CommonUse.CommonModule("EmailOperations");
			If Not ModuleEmailOperations.AvailableEmailSending() Then
				CanCreateAction = False;
			EndIf;
		Else
			CanCreateAction = False;
		EndIf;
	EndIf;
	
	If CanCreateAction AND ((Type = Enums.ContactInformationTypes.WebPage
		Or Type = Enums.ContactInformationTypes.EmailAddress)
		Or (Type = Enums.ContactInformationTypes.Address AND QuantityAddresses > 1)) Then
		
		// There is an action
		CommandName = "Command" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		AddItemDescription(Form, CommandName, 9, True);
		Command.Representation = ButtonRepresentation.Picture;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		
		Item = Form.Items.Add(CommandName,Type("FormButton"), ActionsGroup);
		AddItemDescription(Form, CommandName, 2);
		Item.CommandName = CommandName;
		
		If Type = Enums.ContactInformationTypes.Address Then
			
			Item.Title = NStr("en='Fill';ru='Заполнить'");
			Command.ToolTip = NStr("en='Fill in address from another field';ru='Заполнить адрес из другого поля'");
			Command.Picture = PictureLib.MoveLeft;
			Command.ModifiesStoredData = True;
			
		ElsIf Type = Enums.ContactInformationTypes.WebPage Then
			
			Item.Title = NStr("en='Goto';ru='Перейти'");
			Command.ToolTip = NStr("en='Navigate to link';ru='Перейти по ссылке'");
			Command.Picture = PictureLib.ContactInformationForNavigateLink;
			
		ElsIf Type = Enums.ContactInformationTypes.EmailAddress Then
			
			Item.Title = NStr("en='Write letter';ru='Написать письмо'");
			Command.ToolTip = NStr("en='Write letter';ru='Написать письмо'");
			Command.Picture = PictureLib.SendByEmail;
			
		EndIf;
		
		If IsComment Then
			
			NameStubsActions = "EndCapActions" + AttributeName;
			EndCapActions = Form.Items.Add(NameStubsActions, Type("FormDecoration"), ActionsGroup);
			EndCapActions.Height = 1;
			AddItemDescription(Form, NameStubsActions, 2);
			
		EndIf;
		
	Else
		
		// No action, put a stub.
		NameStubsActions = "EndCapActions" + AttributeName;
		Item = Form.Items.Add(NameStubsActions, Type("FormDecoration"), ActionsGroup);
		AddItemDescription(Form, NameStubsActions, 2);
		If IsComment Then
			Item.Height = 2;
		ElsIf Type = Enums.ContactInformationTypes.Another Then
			Item.Height = 5;
		EndIf;
		
	EndIf;
	
	Return Item;
	
EndFunction

Function Comment(Form, Comment, NameComments, GroupForPosting)
	
	Item = Form.Items.Add(NameComments, Type("FormDecoration"), GroupForPosting);
	Item.Title = Comment;
	
	Item.TextColor = StyleColors.ExplanationText;
	
	Item.HorizontalStretch = True;
	Item.VerticalStretch  = False;
	Item.VerticalAlign  = ItemVerticalAlign.Top;
	
	Item.Height = 1;
	
	AddItemDescription(Form, NameComments, 2);
	
	Return Item;
	
EndFunction

// Deletes separators in phone number.
//
// Parameters:
//    PhoneNumber - String - phone or fax number.
//
// Returns:
//     String - phone or fax number without separators.
//
Function RemoveSeparatorsToPhoneNumber(Val PhoneNumber)
	
	Pos = Find(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	PhoneNumber = StrReplace(PhoneNumber, "-", "");
	PhoneNumber = StrReplace(PhoneNumber, " ", "");
	PhoneNumber = StrReplace(PhoneNumber, "+", "");
	
	Return PhoneNumber;
	
EndFunction

Function VarGroup(GroupName, Form, Parent, Group, DeletionOrder) 
	
	VarGroup = Form.Items.Find(GroupName);
	
	If VarGroup = Undefined Then
		VarGroup = Form.Items.Add(GroupName, Type("FormGroup"), Parent);
		VarGroup.Type = FormGroupType.UsualGroup;
		VarGroup.ShowTitle = False;
		VarGroup.Representation = UsualGroupRepresentation.None;
		VarGroup.Group = Group;
		AddItemDescription(Form, GroupName, DeletionOrder);
		
	EndIf;
	
	Return VarGroup;
	
EndFunction

Procedure CheckContactInformationAttributesPresence(Form, ArrayOfAddedDetails)
	
	FormAttributesList = Form.GetAttributes();
	
	CreateContactInformationParameters = True;
	CreateContactInformationTable = True;
	For Each Attribute In FormAttributesList Do
		If Attribute.Name = "ContactInformationParameters" Then
			CreateContactInformationParameters = False;
		ElsIf Attribute.Name = "ContactInformationAdditionalAttributeInfo" Then
			CreateContactInformationTable = False;
		EndIf;
	EndDo;
	
	If CreateContactInformationTable Then
		
		String500 = New TypeDescription("String", , New StringQualifiers(500));
		
		// Create values table
		DescriptionName = "ContactInformationAdditionalAttributeInfo";
		ArrayOfAddedDetails.Add(New FormAttribute(DescriptionName, New TypeDescription("ValueTable")));
		ArrayOfAddedDetails.Add(New FormAttribute("AttributeName", String500, DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationTypes"), DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("FieldsValues", New TypeDescription("ValueList, String"), DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("Presentation", String500, DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("Comment", New TypeDescription("String"), DescriptionName));
		ArrayOfAddedDetails.Add(New FormAttribute("ThisAttributeOfTabularSection", New TypeDescription("Boolean"), DescriptionName));
		
	EndIf;
	
	If CreateContactInformationParameters Then
		
		ArrayOfAddedDetails.Add(New FormAttribute("ContactInformationParameters", New TypeDescription()));
		
	EndIf;
	
EndProcedure

Procedure SetCheckAttributesValue(Object, VerificationSettings = Undefined)
	
	Object.CheckCorrectness = ?(VerificationSettings = Undefined, False, VerificationSettings.CheckCorrectness);
	If Object.Type = Enums.ContactInformationTypes.Address Then
		Object.CheckByFIAS       = ?(VerificationSettings = Undefined, False, VerificationSettings.CheckByFIAS);
	EndIf;
	
	Object.AddressRussianOnly = False;
	Object.IncludeCountryInPresentation = False;
	Object.ProhibitEntryOfIncorrect =?(VerificationSettings = Undefined, False, VerificationSettings.ProhibitEntryOfIncorrect);
	Object.HideObsoleteAddresses = False;
	
EndProcedure

Procedure AddAttributeToDescription(Form, CIRow, IsNewCIKind, ThisAttributeOfTabularSection = False, FillAttributeValue = True)
	
	NewRow = Form.ContactInformationAdditionalAttributeInfo.Add();
	NewRow.AttributeName  = CIRow.AttributeName;
	NewRow.Kind           = CIRow.Kind;
	NewRow.Type           = CIRow.Type;
	NewRow.ThisAttributeOfTabularSection = ThisAttributeOfTabularSection;
	
	If IsBlankString(CIRow.FieldsValues) Then
		NewRow.FieldsValues = "";
	Else
		NewRow.FieldsValues = ContactInformationManagementClientServer.ConvertStringToFieldList(CIRow.FieldsValues);
	EndIf;
	
	NewRow.Presentation = CIRow.Presentation;
	NewRow.Comment   = CIRow.Comment;
	
	If FillAttributeValue AND Not ThisAttributeOfTabularSection Then
		
		Form[CIRow.AttributeName] = CIRow.Presentation;
		
	EndIf;
	
	StructureCIKind = ContactInformationManagementService.StructureTypeContactInformation(CIRow.Kind);
	StructureCIKind.Insert("Ref", CIRow.Kind);
	
	If IsNewCIKind AND StructureCIKind.AllowInputOfMultipleValues AND Not ThisAttributeOfTabularSection Then
		
		Form.ContactInformationParameters.AddedItemsList.Add(StructureCIKind, CIRow.Kind.Description);
		
	EndIf;
	
EndProcedure

Procedure DeleteCommandsAndFormItems(Form)
	
	AddedElements = Form.ContactInformationParameters.AddedElements;
	AddedElements.SortByPresentation();
	
	For Each ElementToDelete In AddedElements Do
		
		If ElementToDelete.Check Then
			Form.Commands.Delete(Form.Commands[ElementToDelete.Value]);
		Else
			Form.Items.Delete(Form.Items[ElementToDelete.Value]);
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns whether editing in dialog by the contact information type is available.
//
// Parameters:
//    Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//    Boolean - whether editing is available in dialog.
//
Function ForContactInformationTypeAvailableEditInDialog(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns document tabular section name by the contact information kind.
//
// Parameters:
//    CIKind      - CatalogRef.ContactInformationTypes - kind of contact information.
//    ObjectName - String - full name of metadata object.
//
// Returns:
//    String - tabular section name of an empty string if there is no tabular section.
//
Function TabularSectionNameByCI(CIKind, ObjectName) Export
	
	GroupTypeKI = CommonUse.ObjectAttributeValue(CIKind, "Parent");
	NameKindKI = CommonUse.PredefinedName(GroupTypeKI);
	Pos = Find(NameKindKI, ObjectName);
	
	Return Mid(NameKindKI, Pos + StrLen(ObjectName));
	
EndFunction

// Checks whether there are filled in CI strings of the same kind in form (except of the current one).
//
Function HasOtherFilledThisKingCIRows(Val Form, Val CheckedString, Val ContactInformationKind)
	
	AllStringsThisKind = Form.ContactInformationAdditionalAttributeInfo.FindRows(
		New Structure("Kind", ContactInformationKind)
	);
	
	For Each StringKind In AllStringsThisKind Do
		
		If StringKind <> CheckedString Then
			Presentation = Form[StringKind.AttributeName];
			If Not IsBlankString(Presentation) Then 
				Return True;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Procedure OutputMessageToUser(MessageText, AttributeName, AttributeField)
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	CommonUseClientServer.MessageToUser(MessageText,,AttributeField, AttributeName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Filling additional attributes of the "Contact information" tabular section.

// Fills in additional attributes of the "Contact information" tabular section for address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - filled "Contact information" tabular section row.
//    Source             - XDTODataObject  - contact information.
//
Procedure FillTabularSectionForAddressAttributes(TabularSectionRow, Source)
	
	// Defaults
	TabularSectionRow.Country = "";
	TabularSectionRow.State = "";
	TabularSectionRow.City  = "";
	
	Address = Source.Content;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	IsAddress = TypeOf(Address) = Type("XDTODataObject") AND Address.Type() = XDTOFactory.Type(TargetNamespace, "Address");
	If IsAddress AND Address.Content <> Undefined Then 
		TabularSectionRow.Country = Address.Country;
		AddressRF = ContactInformationManagementService.RussianAddress(Address);
		If AddressRF <> Undefined Then
			// Russian address
			TabularSectionRow.State = AddressRF.RFTerritorialEntity;
			TabularSectionRow.City  = AddressRF.City;
		EndIf;
	EndIf;
	
EndProcedure

// Fills in additional attributes of the "Contact information" tabular section for email address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - filled "Contact information" tabular section row.
//    Source             - XDTODataObject  - contact information.
//
Procedure FillTabularSectionForEMailAddressAttributes(TabularSectionRow, Source)
	
	Result = CommonUseClientServer.ParseStringWithPostalAddresses(TabularSectionRow.Presentation, False);
	
	If Result.Count() > 0 Then
		TabularSectionRow.EMail_Address = Result[0].Address;
		
		Pos = Find(TabularSectionRow.EMail_Address, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EMail_Address, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// Fills in additional attributes of the "Contact information" tabular section for phone and address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - filled "Contact information" tabular section row.
//    Source             - XDTODataObject  - contact information.
//
Procedure FillTabularSectionForPhoneAttributes(TabularSectionRow, Source)
	
	// Defaults
	TabularSectionRow.PhoneNumberNoCodes = "";
	TabularSectionRow.PhoneNumber         = "";
	
	Phone = Source.Content;
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If Phone <> Undefined AND Phone.Type() = XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
		CountryCode     = Phone.CountryCode;
		CityCode     = Phone.CityCode;
		PhoneNumber = Phone.Number;
		
		If Left(CountryCode, 1) = "+" Then
			CountryCode = Mid(CountryCode, 2);
		EndIf;
		
		Pos = Find(PhoneNumber, ",");
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		Pos = Find(PhoneNumber, Chars.LF);
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		TabularSectionRow.PhoneNumberNoCodes = RemoveSeparatorsToPhoneNumber(PhoneNumber);
		TabularSectionRow.PhoneNumber         = RemoveSeparatorsToPhoneNumber(String(CountryCode) + CityCode + PhoneNumber);
	EndIf;
	
EndProcedure

// Fills in additional attributes of the "Contact information" tabular section for phone and address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - filled "Contact information" tabular section row.
//    Source             - XDTODataObject  - contact information.
//
Procedure FillTabularSectionForWebpageAttributes(TabularSectionRow, Source)
	
	// Defaults
	TabularSectionRow.ServerDomainName = "";
	
	PageAddress = Source.Content;
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If PageAddress <> Undefined AND PageAddress.Type() = XDTOFactory.Type(TargetNamespace, "WebSite") Then
		AddressByString = PageAddress.Value;
		
		// Delete protocol
		ServerAddress = Right(AddressByString, StrLen(AddressByString) - Find(AddressByString, "://") );
		Pos = Find(ServerAddress, "/");
		// Delete path
		ServerAddress = ?(Pos = 0, ServerAddress, Left(ServerAddress,  Pos-1));
		
		TabularSectionRow.ServerDomainName = ServerAddress;
		
	EndIf;
	
EndProcedure

// Fills in contact information in the receiver "Contact information" tabular section.
//
// Parameters:
//        * Receiver    - Arbitrary - Object in which you need to fill in CI.
//        * KindCI       - CatalogRef.ContactInformationTypes - contact information kind filled
//                                                                    in in the receiver.
//        * StructureCI - ValuesList, String, Structure - contact information fields of values data.
//        * TabularSectionRow - TabularSectionRow, Undefined - receiver data if contact
//                                 information is filled in for a string.
//                                                                      Undefined if
//                                                                      contact information is filled in for a receiver.
//
Procedure FillContactInformationTableParts(Receiver, CIKind, CIStructure, TabularSectionRow = Undefined)
	
	FilterParameters = New Structure;
	If TabularSectionRow = Undefined Then
		FillingData = Receiver;
	Else
		FillingData = TabularSectionRow;
		FilterParameters.Insert("RowIdTableParts", TabularSectionRow.RowIdTableParts);
	EndIf;
	
	FilterParameters.Insert("Kind", CIKind);
	FoundStringsCI = Receiver.ContactInformation.FindRows(FilterParameters);
	If FoundStringsCI.Count() = 0 Then
		CIRow = Receiver.ContactInformation.Add();
		If TabularSectionRow <> Undefined Then
			CIRow.RowIdTableParts = TabularSectionRow.RowIdTableParts;
		EndIf;
	Else
		CIRow = FoundStringsCI[0];
	EndIf;
	
	// From any understood - in XML.
	FieldsValues = XMLContactInformation(CIStructure, , CIKind);
	Presentation = PresentationContactInformation(FieldsValues);
	
	CIRow.Type           = CIKind.Type;
	CIRow.Type           = CIKind;
	CIRow.Presentation = Presentation;
	CIRow.FieldsValues = FieldsValues;
	
	FillAdditionalAttributesContactInformation(CIRow, Presentation, FieldsValues);
EndProcedure

// Checks email contact information and informs about errors. 
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function FillEMailErrors(Source, InformationKind, Val AttributeName = "", AttributeField = "")
	
	If Not InformationKind.CheckCorrectness Then
		Return 0;
	EndIf;
	
	ErrorString = "";
	
	EMail_Address = Source.Content;
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If EMail_Address <> Undefined AND EMail_Address.Type() = XDTOFactory.Type(TargetNamespace, "Email") Then
		Try
			Result = CommonUseClientServer.ParseStringWithPostalAddresses(EMail_Address.Value);
			If Result.Count() > 1 Then
				
				ErrorString = NStr("en='Entry of the single email address is permitted';ru='Допускается ввод только одного адреса электронной почты'");
				
			EndIf;
		Except
			ErrorString = BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	If Not IsBlankString(ErrorString) Then
		OutputMessageToUser(ErrorString, AttributeName, AttributeField);
		ErrorsLevel = ?(InformationKind.ProhibitEntryOfIncorrect, 2, 1);
	Else
		ErrorsLevel = 0;
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

// Fills in additional attributes of the "Contact information" tabular section string.
//
// Parameters:
//    CIRow      - TabularSectionRow - string "Contact information".
//    Presentation - String                     - value presentation.
//    FieldsValues - ValueList, XDTOObject - fields value.
//
Procedure FillAdditionalAttributesContactInformation(CIRow, Presentation, FieldsValues)
	
	If TypeOf(FieldsValues) = Type("XDTODataObject") Then
		ObjectCI = FieldsValues;
	Else
		ObjectCI = ContactInformationManagementService.ContactInformationFromXML(FieldsValues, CIRow.Type);
	EndIf;
	
	InformationType = CIRow.Type;

	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionForEMailAddressAttributes(CIRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionForAddressAttributes(CIRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionForPhoneAttributes(CIRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionForPhoneAttributes(CIRow, ObjectCI);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionForWebpageAttributes(CIRow, ObjectCI);
		
	EndIf;
	
EndProcedure

// Checks contact information and writes it to the values table.
//
Function ValidateContactInformation(Presentation, FieldsValues, InformationKind, InformationType,
	AttributeName, Comment = Undefined, PathToAttribute = "")
	
	SerializationText = ?(IsBlankString(FieldsValues), Presentation, FieldsValues);
	
	ObjectCI = ContactInformationManagementService.ContactInformationFromXML(SerializationText, InformationKind);
	If Comment <> Undefined Then
		ObjectCI.Comment = Comment;
	EndIf;
	ObjectCI.Presentation = Presentation;
	
	FieldsValues = ContactInformationManagementService.ContactInformationXDTOVXML(ObjectCI);
	
	If IsBlankString(Presentation) AND IsBlankString(ObjectCI.Comment) Then
		Return 0;
	EndIf;
	
	// Checking
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		LevelErrors = FillEMailErrors(ObjectCI, InformationKind, AttributeName, PathToAttribute);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		LevelErrors = AddressFillingErrors(ObjectCI.Content, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		LevelErrors = PhoneFillingErrors(ObjectCI, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		LevelErrors = PhoneFillingErrors(ObjectCI, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		LevelErrors = ErrorsFillWebPages(ObjectCI, InformationKind, AttributeName);
	Else
		// Do not check other.
		LevelErrors = 0;
	EndIf;
	
	Return LevelErrors;
	
EndFunction

// Checks address contact information and informs about errors. Returns errors check box.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function AddressFillingErrors(Source, InformationKind, AttributeName = "", AttributeField = "") Export
	
	If Not InformationKind.CheckCorrectness Then
		Return 0;
	EndIf;
	HasErrors = False;
	
	If Not ContactInformationManagementService.ItsRussianAddress(Source) Then
		Return 0;
	EndIf;
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If Source <> Undefined AND Source.Type() = XDTOFactory.Type(TargetNamespace, "Address") Then
		Address = Source;
	Else
		Address = Source.Content;
	EndIf;
	
	If Address <> Undefined AND Address.Type() = XDTOFactory.Type(TargetNamespace, "Address") Then
		ErrorList = ContactInformationManagementService.AddressFillingErrorsXDTO(Address, InformationKind);
		For Each Item In ErrorList Do
			OutputMessageToUser(Item.Presentation, AttributeName, AttributeField);
			HasErrors = True;
		EndDo;
	EndIf;
	
	If HasErrors AND InformationKind.ProhibitEntryOfIncorrect Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
EndFunction

// Checks phone contact information and informs about errors. Returns errors check box.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function PhoneFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

// Checks web page contact information and informs about errors. Returns errors check box.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function ErrorsFillWebPages(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

Procedure ObjectContactInformationFillingDataProcessor(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Name if there is one in the object-receiver.
	Description = Undefined;
	If FillingData.Property("Description", Description) 
		AND IsObjectAttribute("Description", Object) 
	Then
		Object.Description = Description;
	EndIf;
	
	// Contact information table, filled in only if CI is not in another TS.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		AND IsObjectAttribute("ContactInformation", Object) 
	Then
	
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns = ContactInformation.Columns;
		Else
			TableColumns = ContactInformation.UnloadColumns().Columns;
		EndIf;
		
		If TableColumns.Find("RowIdTableParts") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldsValues");
				NewCIRow.FieldsValues = XMLContactInformation(CIRow.FieldsValues, CIRow.Presentation, CIRow.Type);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Determines whether object has attribute with the specified name.
//
// Parameters:
//     AttributeName - String       - Attribute name presence of which is checked.
//     Object       - Arbitrary - Checking object.
//
// Returns:
//     Boolean - checking result.
//
Function IsObjectAttribute(Val AttributeName, Val Object)
	CheckAttribute = New Structure(AttributeName, Undefined);
	FillPropertyValues(CheckAttribute, Object);
	If CheckAttribute[AttributeName] <> Undefined Then
		Return True;
	EndIf;
	
	CheckAttribute[AttributeName] = "";
	FillPropertyValues(CheckAttribute, Object);
	Return CheckAttribute.Description = Undefined;
EndFunction

#EndRegion
