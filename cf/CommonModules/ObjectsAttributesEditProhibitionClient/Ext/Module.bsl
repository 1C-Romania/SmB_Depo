////////////////////////////////////////////////////////////////////////////////
// Subsystem "Prohibition of object attributes editing"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Allows to edit locked form items associated with the given attributes.
//
// Parameters:
//  Form        - ManagedForm - the form on
//                 which it is necessary to allow editing the form items, specified attributes.
//
//  ContinuationProcessor - Undefined - no actions after completion of the procedure.
//                       - NotifyDescription - notification that is called after completing the procedure.
//                         Boolean type parameter is transmitted to the notifications data processor:
//                           True - refs are not detected or user
//                           decided to enable editing, False   - there are no visible
//                                    locked attributes or references detected, and user refused to continue.
//
Procedure AllowObjectAttributesEditing(Val Form, ContinuationProcessor = Undefined) Export
	
	BlockedAttributes = Attributes(Form);
	
	If BlockedAttributes.Count() = 0 Then
		ShowMessageBoxAllVisibleAttributesUnlocked(
			New NotifyDescription("AuthorizeObjectAttributesEditingAfterWarning",
				ObjectsAttributesEditProhibitionServiceClient, ContinuationProcessor));
		Return;
	EndIf;
	
	SynonymsOfAttributes = New Array;
	
	For Each AttributeFullName IN Form.AttributesEditProhibitionParameters Do
		If BlockedAttributes.Find(AttributeFullName.AttributeName) <> Undefined Then
			SynonymsOfAttributes.Add(AttributeFullName.Presentation);
		EndIf;
	EndDo;
	
	RefArray = New Array;
	RefArray.Add(Form.Object.Ref);
	
	Parameters = New Structure;
	Parameters.Insert("Form", Form);
	Parameters.Insert("BlockedAttributes", BlockedAttributes);
	Parameters.Insert("ContinuationProcessor", ContinuationProcessor);
	
	CheckReferencesToObject(
		New NotifyDescription("AuthorizeObjectAttributesEditingAfterRefsCheck",
			ObjectsAttributesEditProhibitionServiceClient, Parameters),
		RefArray,
		SynonymsOfAttributes);
	
EndProcedure

// Sets the availability of the form items
// associated with specified attributes for which change permission is enabled. Ifthe array of
// attributes is passed, then first an attribute set allowed for change will be added.
//   If unlock of form items associated with
// the specified attributes is disabled for all attributes, then edit permissions button is locked.
//  
// Parameters:
//  Form        - ManagedForm - the form on
//                 which it is necessary to allow editing the form items, specified attributes.
//  
//  Attributes    - Array - values:
//                  * String - names of the attributes for which it is necessary to set the permission to change.
//                    Used when the function AuthorizeObjectAttributesEditing is not used.
//               - Undefined - the content of editable attributes does
//                 not change, and the availability is set for the form
//                 items associated with the attributes allowed to be edited.
//
Procedure SetEnabledOfFormItems(Val Form, Val Attributes = Undefined) Export
	
	SetAllowingAttributesEditing(Form, Attributes);
	
	For Each DescriptionOfBlockedAttribute IN Form.AttributesEditProhibitionParameters Do
		If DescriptionOfBlockedAttribute.EditAllowed Then
			For Each BlockedFormItem IN DescriptionOfBlockedAttribute.BlockedItems Do
				FormItem = Form.Items.Find(BlockedFormItem.Value);
				If FormItem <> Undefined Then
					If TypeOf(FormItem) = Type("FormField")
					 OR TypeOf(FormItem) = Type("FormTable") Then
						FormItem.ReadOnly = False;
					Else
						FormItem.Enabled = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Prompts the user to confirm the
// enabling of the attributes editing, and checks if there are refs to the object in the infobase.
//
// Parameters:
//  ContinuationProcessor - NotifyDescription - notification that is called after checking.
//                         Boolean type parameter is transmitted to the notifications data processor:
//                           True - refs are not detected or user
//                           decided to enable editing, False   - there are no visible
//                                    locked attributes or references detected, and user refused to continue.
//  RefArray         - Array - values:
//                           * Ref - searched references in various objects.
//  SynonymsOfAttributes   - Array - values:
//                           * String - attribute synonyms that are shown to the user.
//
Procedure CheckReferencesToObject(Val ContinuationProcessor, Val RefArray, Val SynonymsOfAttributes) Export
	
	DialogTitle = NStr("en='Allow editing attributes';ru='Разрешение редактирования реквизитов'");
	
	AttributesPresentation = "";
	For Each AttributesSynonym IN SynonymsOfAttributes Do
		AttributesPresentation = AttributesPresentation + AttributesSynonym + "," + Chars.LF;
	EndDo;
	AttributesPresentation = Left(AttributesPresentation, StrLen(AttributesPresentation) - 2);
	
	If SynonymsOfAttributes.Count() > 1 Then
		QuestionText = NStr("en='To avoid misalignment of data in the application,
		|the attributes are not editable as follows: 
		|%1.
		|
		|Before permitting their edit, it is recommended to evaluate the consequences
		|by checking all places of this item usage in the application.
		|Search of usage places can take a long time.'; ru = 'Для того чтобы не допустить рассогласования данных в программе,
		|следующие реквизиты не доступны для редактирования: 
		|%1.
		|
		|Перед тем, как разрешить их редактирование, рекомендуется оценить последствия,
		|проверив все места использования этого элемента в программе.
		|Поиск мест использования может занять длительное время.'");
								  
	Else
		QuestionText = NStr("en='To avoid misalignment of data in the application,
		|the %1 attribute is not editable.
		|
		|Before permitting its edit, it is recommended to evaluate the consequences
		|by checking all places of the ""%2"" item usage in the application.
		|Search of usage places can take a long time.'; ru = 'Для того чтобы не допустить рассогласования данных в программе,
		|реквизит %1 не доступен для редактирования.
		|
		|Перед тем, как разрешить его редактирование, рекомендуется оценить последствия,
		|проверив все места использования ""%2"" в программе.
		|Поиск мест использования может занять длительное время.'");
	EndIf;
	
	If RefArray.Count() = 1 Then
		ObjectsPresentation = RefArray[0];
	Else
		ObjectsPresentation = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en='selected items (%1)';ru='выбранных элементов (%1)'"), RefArray.Count());
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, AttributesPresentation, ObjectsPresentation);
	
	Parameters = New Structure;
	Parameters.Insert("RefArray", RefArray);
	Parameters.Insert("SynonymsOfAttributes", SynonymsOfAttributes);
	Parameters.Insert("DialogTitle", DialogTitle);
	Parameters.Insert("ContinuationProcessor", ContinuationProcessor);
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en='Check and allow';ru='Проверить и разрешить'"));
	Buttons.Add(DialogReturnCode.No, NStr("en='Cancel';ru='Отменить'"));
	
	ShowQueryBox(
		New NotifyDescription("CheckReferencesToObjectAfterCheckConfirmation",
			ObjectsAttributesEditProhibitionServiceClient, Parameters),
		QuestionText, Buttons, , DialogReturnCode.Yes, DialogTitle);
	
EndProcedure

// Permits or prohibits the edit of those attributes the description of which is prepared in a form.
//  Used when the form items availability changes
// independently without using function SetFormItemsEnabled.
// 
// Parameters:
//  Form        - ManagedForm - form that requires permission to edit the object attributes.
//  
//  Attributes    - Array - values.
//                  * String - names of the attributes that are to be marked as editable.
//  
//  EditAllowed - Boolean - the value of permission to edit the attributes, the value which is to be defined.
//                            The value will not be set to true, unless there is no right to edit the attribute.
//                          - Undefined - not to change the permission to edit attributes.
// 
//  EditingRight - Boolean - allows to override and define
//                        the option to unlock the attributes, this option is calculated automatically using the AccessRight method.
//                      - Undefined - not to change property EditingRight.
// 
Procedure SetAllowingAttributesEditing(Val Form, Val Attributes,
			Val EditAllowed = True, Val EditingRight = Undefined) Export
	
	If TypeOf(Attributes) = Type("Array") Then
		
		For Each Attribute IN Attributes Do
			AttributeFullName = Form.AttributesEditProhibitionParameters.FindRows(New Structure("AttributeName", Attribute))[0];
			If TypeOf(EditingRight) = Type("Boolean") Then
				AttributeFullName.EditingRight = EditingRight;
			EndIf;
			If TypeOf(EditAllowed) = Type("Boolean") Then
				AttributeFullName.EditAllowed = AttributeFullName.EditingRight AND EditAllowed;
			EndIf;
		EndDo;
	EndIf;
	
	// Command accessibility update AllowObjectAttributessEditing.
	AllAttributesUnlocked = True;
	
	For Each DescriptionOfBlockedAttribute IN Form.AttributesEditProhibitionParameters Do
		If DescriptionOfBlockedAttribute.EditingRight
		AND Not DescriptionOfBlockedAttribute.EditAllowed Then
			AllAttributesUnlocked = False;
			Break;
		EndIf;
	EndDo;
	
	If AllAttributesUnlocked Then
		Form.Items.AllowObjectAttributesEditing.Enabled = False;
	EndIf;
	
EndProcedure

// Returns the array of attribute names that are
// specified in the AttributesEditProhibitionParameters form property on the basis of the
// attribute names referred to in the object manager module, except the attributes for which EditingRight = False.
//
// Parameters:
//  Form         - ManagedForm - object form with mandatory standard attribute "Object".
//  OnlyBlocked - Boolean - for auxilary purpose you can set
//                  False to get a list of all visible attributes that can be unlocked.
//  OnlyVisible - Boolean - to get and unlock all object attributes, it is necessary to set False.
//
// Returns:
//  Array - values:
//   * String - attribute names.
//
Function Attributes(Val Form, Val OnlyBlocked = True, OnlyVisible = True) Export
	
	Attributes = New Array;
	
	For Each DescriptionOfBlockedAttribute IN Form.AttributesEditProhibitionParameters Do
		
		If DescriptionOfBlockedAttribute.EditingRight
		   AND (    DescriptionOfBlockedAttribute.EditAllowed = False
		      OR OnlyBlocked = False) Then
			
			AddAttribute = False;
			For Each BlockedFormItem IN DescriptionOfBlockedAttribute.BlockedItems Do
				FormItem = Form.Items.Find(BlockedFormItem.Value);
				If FormItem <> Undefined AND (FormItem.Visible Or Not OnlyVisible) Then
					AddAttribute = True;
					Break;
				EndIf;
			EndDo;
			If AddAttribute Then
				Attributes.Add(DescriptionOfBlockedAttribute.AttributeName);
			EndIf;
		EndIf;
	EndDo;
	
	Return Attributes;
	
EndFunction

// Shows warning saying that all visible attributes are unlocked.
// It is necessary to show
// warning when in case the unlock command remains enabled due to the existence of invisible unlocked attributes.
//
// Parameters:
//  ContinuationProcessor - Undefined - no actions after completion of the procedure.
//                       - NotifyDescription - notification that is called after completing the procedure.
//
Procedure ShowMessageBoxAllVisibleAttributesUnlocked(ContinuationProcessor = Undefined) Export
	
	ShowMessageBox(ContinuationProcessor,
		NStr("en='Editing all visible object attributes allowed.';ru='Редактирование всех видимых реквизитов объекта уже разрешено.'"));
	
EndProcedure

// Outdated. You should use the Attributes function.
Function AttributesExceptInvisibles(Val Form, Val OnlyBlocked = True) Export
	
	Return Attributes(Form, OnlyBlocked);
	
EndFunction

#EndRegion
