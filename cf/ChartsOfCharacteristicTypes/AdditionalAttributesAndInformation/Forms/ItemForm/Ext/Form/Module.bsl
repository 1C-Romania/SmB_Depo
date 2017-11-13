&AtClient
Var ContinuationProcessorOnWriteError;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Subsystem handler of the objects attributes editing prohibition.
	ObjectsAttributesEditProhibition.LockAttributes(ThisObject);
	
	CurrentSetOfProperties = Parameters.CurrentSetOfProperties;
	
	If ValueIsFilled(Object.Ref) Then
		Items.ThisIsAdditionalInformation.Enabled = False;
		ShowUpdateSet = Parameters.ShowUpdateSet;
	Else
		If ValueIsFilled(CurrentSetOfProperties) Then
			Object.PropertySet = CurrentSetOfProperties;
		EndIf;
		
		If ValueIsFilled(Parameters.AdditionalValuesOwner) Then
			Object.AdditionalValuesOwner = Parameters.AdditionalValuesOwner;
		EndIf;
		
		If Parameters.ThisIsAdditionalInformation <> Undefined Then
			Object.ThisIsAdditionalInformation = Parameters.ThisIsAdditionalInformation;
			
		ElsIf Not ValueIsFilled(Parameters.CopyingValue) Then
			Items.ThisIsAdditionalInformation.Visible = True;
		EndIf;
	EndIf;
	
	If Object.Predefined AND Not ValueIsFilled(Object.Title) Then
		Object.Title = Object.Description;
	EndIf;
	
	ThisIsAdditionalInformation = ?(Object.ThisIsAdditionalInformation, 1, 0);
	
	RefreshContentOfFormItems();
	
	If Object.MultilineTextBox > 0 Then
		MultilineTextBox = True;
		MultilineTextBoxNumber = Object.MultilineTextBox;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation") Then
		Close();
		
		// Ownership form opening.
		FormParameters = New Structure;
		FormParameters.Insert("Key", ValueSelected);
		FormParameters.Insert("CurrentSetOfProperties", CurrentSetOfProperties);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm",
			FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("WhenNameIsAlreadyUsed") Then
	
		// Filling the name according
		// to set of properties, and check if there is a property with the same name.
		QuestionText = NameIsAlreadyUsed(
			Object.Title, Object.Ref, Object.PropertySet, Object.Description);
		
		If ValueIsFilled(QuestionText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("en='Continue writing';ru='Продолжить запись'"));
			Buttons.Add("BackToEnteringNames", NStr("en='Return to name input';ru='Вернуться к вводу наименования'"));
			
			ShowQueryBox(
				New NotifyDescription("AfterAnswerToAQuestionWhenNameIsAlreadyUsed", ThisObject, WriteParameters),
				QuestionText, Buttons, , "BackToEnteringNames");
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	If WriteParameters.Property("ContinuationProcessor") Then
		ContinuationProcessorOnWriteError = WriteParameters.ContinuationProcessor;
		AttachIdleHandler("AfterErrorRecord", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PropertiesManagementService.ValueTypeContainsPropertiesValues(Object.ValueType) Then
		CurrentObject.AdditionalValuesAreUsed = True;
	Else
		CurrentObject.AdditionalValuesAreUsed = False;
		CurrentObject.ValueFormHeader = "";
		CurrentObject.ValueChoiceFormHeader = "";
	EndIf;
	
	If Object.ThisIsAdditionalInformation
	 OR Not (    Object.ValueType.ContainsType(Type("Number" ))
	         OR Object.ValueType.ContainsType(Type("Date"  ))
	         OR Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		CurrentObject.FormatProperties = "";
	EndIf;
	
	CurrentObject.MultilineTextBox = 0;
	
	If Not Object.ThisIsAdditionalInformation
	   AND Object.ValueType.Types().Count() = 1
	   AND Object.ValueType.ContainsType(Type("String")) Then
		
		If MultilineTextBox Then
			CurrentObject.MultilineTextBox = MultilineTextBoxNumber;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(CurrentObject.PropertySet) Then
		AddToSet = CurrentObject.PropertySet;
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInformationSets");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Ref", AddToSet);
		Block.Lock();
		LockDataForEdit(AddToSet);
		
		PropertiesSetObject = AddToSet.GetObject();
		If CurrentObject.ThisIsAdditionalInformation Then
			TabularSection = PropertiesSetObject.AdditionalInformation;
		Else
			TabularSection = PropertiesSetObject.AdditionalAttributes;
		EndIf;
		FoundString = TabularSection.Find(CurrentObject.Ref, "Property");
		If FoundString = Undefined Then
			NewRow = TabularSection.Add();
			NewRow.Property = CurrentObject.Ref;
			PropertiesSetObject.Write();
			CurrentObject.AdditionalProperties.Insert("SetChange", AddToSet);
		EndIf;
	EndIf;
	
	If WriteParameters.Property("ClearInputWeightsCoefficients") Then
		ClearInputWeightsCoefficients();
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Subsystem handler of the objects attributes editing prohibition.
	ObjectsAttributesEditProhibition.LockAttributes(ThisObject);
	
	RefreshContentOfFormItems();
	
	If CurrentObject.AdditionalProperties.Property("SetChange") Then
		WriteParameters.Insert("SetChange", CurrentObject.AdditionalProperties.SetChange);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Writing_AdditionalAttributesAndInformation",
		New Structure("Ref", Object.Ref), Object.Ref);
	
	If WriteParameters.Property("SetChange") Then
		
		Notify("Writing_AdditionalAttributesAndInformationSets",
			New Structure("Ref", WriteParameters.SetChange), WriteParameters.SetChange);
	EndIf;
	
	If WriteParameters.Property("ContinuationProcessor") Then
		ContinuationProcessorOnWriteError = Undefined;
		DetachIdleHandler("AfterErrorRecord");
		ExecuteNotifyProcessing(
			New NotifyDescription(WriteParameters.ContinuationProcessor.ProcedureName,
				ThisObject, WriteParameters.ContinuationProcessor.Parameters),
			False);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ThisAdditionalInformationOnChange(Item)
	
	Object.ThisIsAdditionalInformation = ThisIsAdditionalInformation;
	
	RefreshContentOfFormItems();
	
EndProcedure

&AtClient
Procedure ClarificationOfValuesListCommentClick(Item)
	
	WriteObject("TransitionToListOfValues",
		"ValuesListSpecificationCommentClickEnd");
	
EndProcedure

&AtClient
Procedure SetsSpecificationsCommentClick(Item)
	
	WriteObject("TransitionToListOfValues",
		"SetsSpecificationCommentClickContinue");
	
EndProcedure

&AtClient
Procedure ValueTypeOnChange(Item)
	
	WarningText = "";
	RefreshContentOfFormItems(WarningText);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
	   AND Not Object.AdditionalValuesWithWeight Then
		
		QuestionText =
			NStr("en='Clear the entered weight coefficients? Data will be written.';ru='Очистить введенные весовые коэффициенты? Данные будут записаны.'");
		
		Buttons = New ValueList;
		Buttons.Add("ClearAndWrite", NStr("en='Clear and write';ru='Очистить и записать'"));
		Buttons.Add("Cancel", NStr("en='Cancel';ru='Отменить'"));
		
		ShowQueryBox(
			New NotifyDescription("AfterWeightCoefficientsClearingConfirmation", ThisObject),
			QuestionText, Buttons, , "ClearAndWrite");
	Else
		WriteObject("UseWeightChange",
			"AdditionalValuesWithWeightOnChangeEnd");
	EndIf;
	
EndProcedure

&AtClient
Procedure MultilineTextBoxNumberOnChange(Item)
	
	MultilineTextBox = True;
	
EndProcedure

&AtClient
Procedure CommentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CommonUseClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region ValueFormTableItemsEventsHandlers

&AtClient
Procedure ValuesOnChange(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		EventName = "Record_ValuesOfObjectProperties";
	Else
		EventName = "Record_ValuesOfObjectPropertiesHierarchy";
	EndIf;
	
	Notify(EventName,
		New Structure("Ref", Item.CurrentData.Ref),
		Item.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Copy", Copy);
	AdditionalParameters.Insert("Parent", Parent);
	AdditionalParameters.Insert("Group", Group);
	
	WriteObject("TransitionToListOfValues",
		"ValuesBeforeAddingStartEnd", AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ValuesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Items.AdditionalValues.ReadOnly Then
		Return;
	EndIf;
	
	WriteObject("TransitionToListOfValues",
		"ValuesBeforeChangeStartEnd");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EditValueFormat(Command)
	
	Assistant = New FormatStringWizard(Object.FormatProperties);
	
	Assistant.AvailableTypes = Object.ValueType;
	
	Assistant.Show(
		New NotifyDescription("EditValueFormatEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SpecificationOfValuesListChange(Command)
	
	WriteObject("AttributeTypeChange",
		"ValuesListSpecificationChangeEnd");
	
EndProcedure

&AtClient
Procedure SpecificationsSetsChange(Command)
	
	WriteObject("AttributeTypeChange",
		"SetsSpecificationChangeEnd");
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	BlockedAttributes = ObjectsAttributesEditProhibitionClient.Attributes(ThisObject);
	
	If BlockedAttributes.Count() > 0 Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Ref", Object.Ref);
		FormParameters.Insert("ThisIsAdditionalAttribute", Object.ThisIsAdditionalInformation);
		
		Notification = New NotifyDescription("UpdateFormForEdit", ThisObject);
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.Form.AttributeUnlocking",
			FormParameters, ThisObject,,,, Notification);
	Else
		ObjectsAttributesEditProhibitionClient.ShowMessageBoxAllVisibleAttributesUnlocked();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateFormForEdit(Result, Parameter) Export
	#If WebClient Then
		RefreshDataRepresentation();
	#EndIf
EndProcedure

&AtClient
Procedure AfterAnswerToAQuestionWhenNameIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationProcessor") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationProcessor.ProcedureName,
					ThisObject, WriteParameters.ContinuationProcessor.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenNameIsAlreadyUsed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWeightCoefficientsClearingConfirmation(Response, NotSpecified) Export
	
	If Response <> "ClearAndWrite" Then
		Object.AdditionalValuesWithWeight = Not Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ClearInputWeightsCoefficients");
	
	WriteObject("UseWeightChange",
		"AdditionalValuesWithWeightOnChangeEnd",
		,
		WriteParameters);
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChangeEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Object.AdditionalValuesWithWeight = Not Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Notify(
			"Update_ValueIsCharacterizedByWeighting",
			Object.AdditionalValuesWithWeight,
			Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesListSpecificationCommentClickEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowUpdateSet", True);
	FormParameters.Insert("Key", Object.AdditionalValuesOwner);
	FormParameters.Insert("CurrentSetOfProperties", CurrentSetOfProperties);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm",
		FormParameters, FormOwner);
	
EndProcedure

&AtClient
Procedure SetsSpecificationCommentClickContinue(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	SelectedSet = Undefined;
	
	If ListOfSets.Count() > 1 Then
		ShowChooseFromList(
			New NotifyDescription("SetsSpecificationCommentClickEnd", ThisObject),
			ListOfSets, Items.SetsSpecificationsComment);
	Else
		SetsSpecificationCommentClickEnd(, ListOfSets[0].Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetsSpecificationCommentClickEnd(SelectedItem, SelectedSet) Export
	
	If SelectedItem <> Undefined Then
		SelectedSet = SelectedItem.Value;
	EndIf;
	
	If SelectedSet <> Undefined Then
		Close();
		
		ChoiceValue = New Structure;
		ChoiceValue.Insert("Set", SelectedSet);
		ChoiceValue.Insert("Property", Object.Ref);
		ChoiceValue.Insert("ThisIsAdditionalInformation", Object.ThisIsAdditionalInformation);
		NotifyChoice(ChoiceValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddingStartEnd(Cancel, ProcessingParameters) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		TableValuesName = "Catalog.ObjectsPropertiesValues";
	Else
		TableValuesName = "Catalog.ObjectsPropertiesValuesHierarchy";
	EndIf;
	
	FillingValues = New Structure;
	FillingValues.Insert("Parent", ProcessingParameters.Parent);
	FillingValues.Insert("Owner", Object.Ref);
	
	FormParameters = New Structure;
	FormParameters.Insert("HideOwner", True);
	FormParameters.Insert("FillingValues", FillingValues);
	
	If ProcessingParameters.Group Then
		FormParameters.Insert("IsFolder", True);
		
		OpenForm(TableValuesName + ".FolderForm", FormParameters, Items.Values);
	Else
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		
		If ProcessingParameters.Copy Then
			FormParameters.Insert("CopyingValue", Items.Values.CurrentRow);
		EndIf;
		
		OpenForm(TableValuesName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeChangeStartEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		TableValuesName = "Catalog.ObjectsPropertiesValues";
	Else
		TableValuesName = "Catalog.ObjectsPropertiesValuesHierarchy";
	EndIf;
	
	If Items.Values.CurrentRow <> Undefined Then
		// Value form or value group opening.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.Values.CurrentRow);
		
		OpenForm(TableValuesName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesListSpecificationChangeEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentSetOfProperties", CurrentSetOfProperties);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("ThisIsAdditionalInformation", Object.ThisIsAdditionalInformation);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.Form.PropertySettingChange",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetsSpecificationChangeEnd(Cancel, NotSpecified) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentSetOfProperties", CurrentSetOfProperties);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("ThisIsAdditionalInformation", Object.ThisIsAdditionalInformation);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.Form.PropertySettingChange",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure WriteObject(VariantOfTextOfQuestion, ContinuationProcedureName, AdditionalParameters = Undefined, WriteParameters = Undefined)
	
	If ValueIsFilled(Object.Ref) AND Not Modified Then
		
		ExecuteNotifyProcessing(New NotifyDescription(
			ContinuationProcedureName, ThisObject, AdditionalParameters), False);
		Return;
	EndIf;
	
	If WriteParameters = Undefined Then
		WriteParameters = New Structure;
	EndIf;
	
	ContinuationProcessor = New Structure;
	ContinuationProcessor.Insert("ProcedureName", ContinuationProcedureName);
	ContinuationProcessor.Insert("Parameters", AdditionalParameters);
	
	WriteParameters.Insert("ContinuationProcessor", ContinuationProcessor);
	
	If ValueIsFilled(Object.Ref) Then
		WriteObjectContinuation("Write", WriteParameters);
		Return;
	EndIf;
	
	If VariantOfTextOfQuestion = "TransitionToListOfValues" Then
		QuestionText =
			NStr("en='Transition to values
		|list work is possible only after the data record.
		|
		|Data will be written.';ru='Переход
		|к работе со списком значений возможен только после записи данных.
		|
		|Данные будут записаны.'");
	Else
		QuestionText =
			NStr("en='Data will be written.';ru='Данные будут записаны.'")
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Write", NStr("en = 'Write'; ru = 'Записать'"));
	Buttons.Add("Cancel", NStr("en = 'Cancel'; ru = 'Отмена'"));
	
	ShowQueryBox(
		New NotifyDescription(
			"WriteObjectContinuation", ThisObject, WriteParameters),
		QuestionText, Buttons, , "Write");
	
EndProcedure

&AtClient
Procedure WriteObjectContinuation(Response, WriteParameters) Export
	
	If Response <> "Write" Then
		Return;
	EndIf;
	
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterErrorRecord()
	
	If ContinuationProcessorOnWriteError <> Undefined Then
		ExecuteNotifyProcessing(
			New NotifyDescription(ContinuationProcessorOnWriteError.ProcedureName,
				ThisObject, ContinuationProcessorOnWriteError.Parameters),
			True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditValueFormatEnd(Text, NotSpecified) Export
	
	If Text <> Undefined Then
		Object.FormatProperties = Text;
		SetTitleOfFormatButton(ThisObject);
		
		WarningText = "";
		Array = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Text, ";");
		
		For Each Substring IN Array Do
			If Find(Substring, "DP=") > 0 OR Find(Substring, "DE=") > 0 Then
				WarningText = WarningText + Chars.LF +
					NStr("en='Date fields cannot be left blank.';ru='Представление пустой даты не поддерживается в полях ввода.'");
				Continue;
			EndIf;
			If Find(Substring, "NZ=") > 0 OR Find(Substring, "NZ=") > 0 Then
				WarningText = WarningText + Chars.LF +
					NStr("en='Input fields cannot be left blank.';ru='Представление пустого числа не поддерживается в полях ввода.'");
				Continue;
			EndIf;
			If Find(Substring, "DF=") > 0 OR Find(Substring, "DF=") > 0 Then
				If Find(Substring, "ddd") > 0 OR Find(Substring, "ddd") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en='Multiple name of day of the week is not supported in input fields.';ru='Кратное название дня недели не поддерживается в полях ввода.'");
				EndIf;
				If Find(Substring, "dddd") > 0 OR Find(Substring, "dddd") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en='Full name of the weekday is not supported in input fields.';ru='Полное название дня недели не поддерживается в полях ввода.'");
				EndIf;
				If Find(Substring, "MMM") > 0 OR Find(Substring, "MMM") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en='Short month name is not supported in input fields.';ru='Кратное название месяца не поддерживается в полях ввода.'");
				EndIf;
				If Find(Substring, "MMMM") > 0 OR Find(Substring, "MMMM") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en='Full month name is not supported in input fields.';ru='Полное название месяца не поддерживается в полях ввода.'");
				EndIf;
			EndIf;
			If Find(Substring, "DLF=") > 0 OR Find(Substring, "DLF=") > 0 Then
				If Find(Substring, "DD") > 0 OR Find(Substring, "DD") > 0 Then
					WarningText = WarningText + Chars.LF +
						NStr("en='Long date (month in words) is not supported in input fields.';ru='Длинная дата (месяц прописью) не поддерживается в полях ввода.'");
				EndIf;
			EndIf;
		EndDo;
		
		If ValueIsFilled(WarningText) Then
			WarningText = WarningText + Chars.LF +
				NStr("en='There are no restrictions in the usage locations of the label fields.';ru='В местах использования полей надписей ограничений нет.'");
			ShowMessageBox(, WarningText);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshContentOfFormItems(WarningText = "")
	
	Title = GetTitle(Object);
	
	If Not Object.ValueType.ContainsType(Type("Number"))
	   AND Not Object.ValueType.ContainsType(Type("Date"))
	   AND Not Object.ValueType.ContainsType(Type("Boolean")) Then
		
		Object.FormatProperties = "";
	EndIf;
	
	SetTitleOfFormatButton(ThisObject);
	
	If Object.ThisIsAdditionalInformation
	 OR Not (    Object.ValueType.ContainsType(Type("Number" ))
	         OR Object.ValueType.ContainsType(Type("Date"  ))
	         OR Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		Items.EditValueFormat.Visible = False;
	Else
		Items.EditValueFormat.Visible = True;
	EndIf;
	
	If Not Object.ThisIsAdditionalInformation
	   AND Object.ValueType.Types().Count() = 1
	   AND Object.ValueType.ContainsType(Type("String")) Then
		
		Items.MultilineGroup.Visible = True;
	Else
		Items.MultilineGroup.Visible = False;
	EndIf;
	
	If Object.ThisIsAdditionalInformation Then
		Object.FillObligatory = False;
		Items.FillObligatory.Visible = False;
	Else
		Items.FillObligatory.Visible = True;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		OldValueType = CommonUse.ObjectAttributeValue(Object.Ref, "ValueType");
	Else
		OldValueType = New TypeDescription;
	EndIf;
	
	If ValueIsFilled(Object.AdditionalValuesOwner) Then
		
		PropertiesOfOwner = CommonUse.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "ValueType, AdditionalValuesWithWeight");
		
		If PropertiesOfOwner.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectsPropertiesValuesHierarchy",
				"CatalogRef.ObjectsPropertiesValues");
		Else
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectsPropertiesValues",
				"CatalogRef.ObjectsPropertiesValuesHierarchy");
		EndIf;
		
		ValueOwner = Object.AdditionalValuesOwner;
		ValuesWithWeight   = PropertiesOfOwner.AdditionalValuesWithWeight;
	Else
		// Checking the possibility to delete additional values type.
		If PropertiesManagementService.ValueTypeContainsPropertiesValues(OldValueType) Then
			Query = New Query;
			Query.SetParameter("Owner", Object.Ref);
			
			If OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectsPropertiesValuesHierarchy AS ObjectsPropertiesValuesHierarchy
				|WHERE
				|	ObjectsPropertiesValuesHierarchy.Owner = &Owner";
			Else
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
				|WHERE
				|	ObjectsPropertiesValues.Owner = &Owner";
			EndIf;
			
			If Not Query.Execute().IsEmpty() Then
				
				If OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy"))
				   AND Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='It is impossible
		|to delet the type ""%1"", as additional values are already input.
		|It is necessary to delete additional input values first.
		|
		|Deleted type is restored.';ru='Недопустимо
		|удалять тип ""%1"", так как дополнительные значения уже введены.
		|Сначала нужно удалить введенные дополнительные значения.
		|
		|Удаленный тип восстановлен.'"),
						String(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectsPropertiesValuesHierarchy",
						"CatalogRef.ObjectsPropertiesValues");
				
				ElsIf OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
				        AND Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='It is impossible
		|to delet the type ""%1"", as additional values are already input.
		|It is necessary to delete additional input values first.
		|
		|Deleted type is restored.';ru='Недопустимо
		|удалять тип ""%1"", так как дополнительные значения уже введены.
		|Сначала нужно удалить введенные дополнительные значения.
		|
		|Удаленный тип восстановлен.'"),
						String(Type("CatalogRef.ObjectsPropertiesValues")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectsPropertiesValues",
						"CatalogRef.ObjectsPropertiesValuesHierarchy");
				EndIf;
			EndIf;
		EndIf;
		
		// Check that no more than one additional values type is set up.
		If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy"))
		   AND Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			If Not OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
				
				WarningText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='It is impossible to
		|use ""%1""
		|and ""%2"" value types simultaneously.
		|
		|Second type deleted.';ru='Недопустимо одновременно
		|использовать
		|типы значения ""%1"" и ""%2"".
		|
		|Второй тип удален.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) );
				
				// Deletion of the second type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectsPropertiesValuesHierarchy");
			Else
				WarningText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='It is impossible to
		|use ""%1""
		|and ""%2"" value types simultaneously.
		|
		|First type deleted.';ru='Недопустимо одновременно
		|использовать
		|типы значения ""%1"" и ""%2"".
		|
		|Первый тип удален.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) );
				
				// Deletion of the first type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectsPropertiesValues");
			EndIf;
		EndIf;
		
		ValueOwner = Object.Ref;
		ValuesWithWeight   = Object.AdditionalValuesWithWeight;
	EndIf;
	
	If PropertiesManagementService.ValueTypeContainsPropertiesValues(Object.ValueType) Then
		Items.GroupFormsValuesHeaders.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.AdditionalValues.Visible = True;
	Else
		Items.GroupFormsValuesHeaders.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.AdditionalValues.Visible = False;
	EndIf;
	
	Items.Values.Header        = ValuesWithWeight;
	Items.ValuesWeight.Visible = ValuesWithWeight;
	
	CommonUseClientServer.SetFilterDynamicListItem(
		Values, "Owner", ValueOwner, , , True);
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		Values.MainTable = "Catalog.ObjectsPropertiesValues";
	Else
		Values.MainTable = "Catalog.ObjectsPropertiesValuesHierarchy";
	EndIf;
	
	// Specifications representation.
	
	If Not ValueIsFilled(Object.AdditionalValuesOwner) Then
		Items.ClarificationOfValuesList.Visible = False;
		Items.AdditionalValues.ReadOnly = False;
		Items.ValuesCommandBarEditing.Visible = True;
		Items.ValuesContextMenuEditing.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.GroupFormsValuesHeaders.Visible = True;
	Else
		Items.ClarificationOfValuesList.Visible = True;
		Items.AdditionalValues.ReadOnly = True;
		Items.ValuesCommandBarEditing.Visible = False;
		Items.ValuesContextMenuEditing.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.GroupFormsValuesHeaders.Visible = False;
		
		Items.ClarificationOfValuesListComment.Hyperlink = ValueIsFilled(Object.Ref);
		Items.SpecificationOfValuesListChange.Enabled    = ValueIsFilled(Object.Ref);
		
		PropertiesOfOwner = CommonUse.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "PropertySet, Title, ThisIsAdditionalInformation");
		
		If PropertiesOfOwner.ThisIsAdditionalInformation <> True Then
			SpecificationTemplate = NStr("en='Common list of values with attribute ""%1"" of set ""%2""';ru='Список значений общий с реквизитом ""%1"" набора ""%2""'");
		Else
			SpecificationTemplate = NStr("en='Common list of values with data ""%1"" of set ""%2""';ru='Список значений общий со сведением ""%1"" набора ""%2""'");
		EndIf;
		
		Items.ClarificationOfValuesListComment.Title =
			StringFunctionsClientServer.SubstituteParametersInString(
				SpecificationTemplate, PropertiesOfOwner.Title, String(PropertiesOfOwner.PropertySet)) + "  ";
	EndIf;
	
	RefreshListSets();
	
	If Not ShowUpdateSet
	   AND ValueIsFilled(Object.PropertySet)
	   AND ListOfSets.Count() < 2 Then
		
		Items.SetsSpecifications.Visible = False;
	Else
		Items.SetsSpecifications.Visible = True;
		Items.SetsSpecificationsComment.Hyperlink =
			ValueIsFilled(Object.Ref) AND ValueIsFilled(CurrentSetOfProperties);
		
		Items.SpecificationsSetsChange.Enabled = ValueIsFilled(Object.Ref);
		
		If ValueIsFilled(Object.PropertySet)
		   AND ListOfSets.Count() < 2 Then
			
			Items.SpecificationsSetsChange.Visible = False;
		
		ElsIf ValueIsFilled(CurrentSetOfProperties) Then
			Items.SpecificationsSetsChange.Visible = True;
		Else
			Items.SpecificationsSetsChange.Visible = False;
		EndIf;
		
		If ListOfSets.Count() > 0 Then
		
			If ValueIsFilled(Object.PropertySet)
			   AND ListOfSets.Count() < 2 Then
				
				If Object.ThisIsAdditionalInformation Then
					SpecificationTemplate = NStr("en='Data is included in set: %1';ru='Сведение входит в набор: %1'");
				Else
					SpecificationTemplate = NStr("en='The attribute belongs to the set: %1';ru='Реквизит входит в набор: %1'");
				EndIf;
				TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(
					SpecificationTemplate, TrimAll(ListOfSets[0].Presentation));
			Else
				If ListOfSets.Count() > 1 Then
					If Object.ThisIsAdditionalInformation Then
						SpecificationTemplate = NStr("en='Common information is included in %1 %2';ru='Общее сведение входит в %1 %2'");
					Else
						SpecificationTemplate = NStr("en='Common attribute is included in %1 %2';ru='Общий реквизит входит в %1 %2'");
					EndIf;
					
					StringSets = TrimAll(NumberInWords(
						ListOfSets.Count(), "ND=False", "Set,set,sets,m,,,,,0"));
					
					While True Do
						Position = Find(StringSets, " ");
						If Position = 0 Then
							Break;
						EndIf;
						StringSets = TrimAll(Mid(StringSets, Position + 1));
					EndDo;
					
					TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(
						SpecificationTemplate, Format(ListOfSets.Count(), "NG="), StringSets);
				Else
					If Object.ThisIsAdditionalInformation Then
						SpecificationTemplate = NStr("en='Common information is included in set: %1';ru='Общее сведение входит в набор: %1'");
					Else
						SpecificationTemplate = NStr("en='Common attribute is included in set: %1';ru='Общий реквизит входит в набор: %1'");
					EndIf;
					
					TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(
						SpecificationTemplate, TrimAll(ListOfSets[0].Presentation));
				EndIf;
			EndIf;
		Else
			Items.SetsSpecificationsComment.Hyperlink = False;
			Items.SpecificationsSetsChange.Visible = False;
			
			If ValueIsFilled(Object.PropertySet) Then
				If Object.ThisIsAdditionalInformation Then
					TextOfComment = NStr("en='Data is not included in the set';ru='Сведение не входит в набор'");
				Else
					TextOfComment = NStr("en='The attribute does not belong to the set';ru='Реквизит не входит в набор'");
				EndIf;
			Else
				If Object.ThisIsAdditionalInformation Then
					TextOfComment = NStr("en='Common information is not included in sets';ru='Общее сведение не входит в наборы'");
				Else
					TextOfComment = NStr("en='Common information is not included in sets';ru='Общее сведение не входит в наборы'");
				EndIf;
			EndIf;
		EndIf;
		
		Items.SetsSpecificationsComment.Title = TextOfComment + " ";
		
		If Items.SetsSpecificationsComment.Hyperlink Then
			Items.SetsSpecificationsComment.ToolTip = NStr("en='Go to set';ru='Переход к набору'");
		Else
			Items.SetsSpecificationsComment.ToolTip = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearInputWeightsCoefficients()
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		TableValuesName = "Catalog.ObjectsPropertiesValues";
	Else
		TableValuesName = "Catalog.ObjectsPropertiesValuesHierarchy";
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add(TableValuesName);
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		Query = New Query;
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValues AS CurrentTable
		|WHERE
		|	CurrentTable.Weight <> 0";
		Query.Text = StrReplace(Query.Text , "Catalog.ObjectsPropertiesValues", TableValuesName);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ValueObject = Selection.Ref.GetObject();
			ValueObject.Weight = 0;
			ValueObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure RefreshListSets()
	
	ListOfSets.Clear();
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	AdditionalAttributes.Ref AS Set,
		|	AdditionalAttributes.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Property = &Property
		|	AND Not AdditionalAttributes.Ref.IsFolder
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalInformation.Ref,
		|	AdditionalInformation.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS AdditionalInformation
		|WHERE
		|	AdditionalInformation.Property = &Property
		|	AND Not AdditionalInformation.Ref.IsFolder");
		
		Query.SetParameter("Property", Object.Ref);
		
		BeginTransaction();
		Try
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				ListOfSets.Add(Selection.Set, Selection.Description + "         ");
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function NameIsAlreadyUsed(Val Title, Val CurrentProperty, Val PropertySet, NewDescription)
	
	If ValueIsFilled(PropertySet) Then
		NameOfSet = CommonUse.ObjectAttributeValue(PropertySet, "Description");
		NewDescription = Title + " (" + NameOfSet + ")";
	Else
		NewDescription = Title;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.ThisIsAdditionalInformation,
	|	Properties.PropertySet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|WHERE
	|	Properties.Description = &Description
	|	AND Properties.Ref <> &Ref";
	
	Query.SetParameter("Ref",       CurrentProperty);
	Query.SetParameter("Description", NewDescription);
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Not Selection.Next() Then
		Return "";
	EndIf;
	
	If ValueIsFilled(Selection.PropertySet) Then
		If Selection.ThisIsAdditionalInformation Then
			QuestionText = NStr("en='There is an additional information with name ""%1"".';ru='Существует дополнительное сведение с наименованием ""%1"".'");
		Else
			QuestionText = NStr("en='There is additional attribute
		|with name ""%1"".';ru='Существует дополнительный
		|реквизит с наименованием ""%1"".'");
		EndIf;
	Else
		If Selection.ThisIsAdditionalInformation Then
			QuestionText = NStr("en='There is common additional information
		|with name ""%1"".';ru='Существует общее дополнительное
		|сведение с наименованием ""%1"".'");
		Else
			QuestionText = NStr("en='There is common additional attribute
		|with name ""%1"".';ru='Существует общий дополнительный
		|реквизит с наименованием ""%1"".'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText + NStr("en='
		|
		|It is recommended
		|to use another name otherwise the applicationm may work incorrectly.';ru='
		|
		|Рекомендуется
		|использовать другое наименование, иначе программа может работать некорректно.'"),
		NewDescription);
	
	Return QuestionText;
	
EndFunction

&AtClientAtServerNoContext
Function GetTitle(Object)
	
	If ValueIsFilled(Object.Ref) Then
		
		If ValueIsFilled(Object.PropertySet) Then
			If Object.ThisIsAdditionalInformation Then
				Title = String(Object.Title) + " " + NStr("en='Additional information';ru='Дополнительная информация'");
			Else
				Title = String(Object.Title) + " " + NStr("en='(Additional attribute)';ru='(Дополнительный реквизит)'");
			EndIf;
		Else
			If Object.ThisIsAdditionalInformation Then
				Title = String(Object.Title) + " " + NStr("en='(Common additional information)';ru='(Общее дополнительное сведение)'");
			Else
				Title = String(Object.Title) + " " + NStr("en='(Common additional attribute)';ru='(Общий дополнительный реквизит)'");
			EndIf;
		EndIf;
	Else
		If ValueIsFilled(Object.PropertySet) Then
			If Object.ThisIsAdditionalInformation Then
				Title = NStr("en='Additional information (creation)';ru='Дополнительное сведение (создание)'");
			Else
				Title = NStr("en='Additional attribute (creation)';ru='Дополнительный реквизит (создание)'");
			EndIf;
		Else
			If Object.ThisIsAdditionalInformation Then
				Title = NStr("en='Common additional information (creation)';ru='Общее дополнительное сведение (создание)'");
			Else
				Title = NStr("en='Common additional attribute (creation)';ru='Общий дополнительный реквизит (создание)'");
			EndIf;
		EndIf;
	EndIf;
	
	Return Title;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetTitleOfFormatButton(Form)
	
	If IsBlankString(Form.Object.FormatProperties) Then
		HeaderText = NStr("en='Default format';ru='Формат по умолчанию'");
	Else
		HeaderText = NStr("en='Format is set';ru='Формат установлен'");
	EndIf;
	
	Form.Items.EditValueFormat.Title = HeaderText;
	
EndProcedure

#EndRegion
