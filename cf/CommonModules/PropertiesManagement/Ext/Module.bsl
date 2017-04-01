////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for standard processing of additional attributes.

// Creates basic attributes and form fields necessary for operation.
// Fills in additional attributes if used.
// Called from handler OnCreateAtServer of object form with properties.
// 
// Parameters:
//  Form - ManagedForm - in which additional attributes will be displayed.
//
//  AdditionalParameters - Undefined - all additional parameters have default values.
//                          - Structure - with optional properties:
//
//    * Object - FormDataStructure - by object type.
//
//    * ItemNameForPlacement - String - name of form group to which the properties will be allocated.
//
//    * RandomObject - Boolean - if True, then the table of additional attributes
//            description is created in the form, parameter Object is ignored, additional attributes are not created and completed.
//
//            It is necessary when one form is consistently used for
//            viewing or editing of additional attributes of dirrerent objects (including different types).
//
//            After executing OnCreateAtServer, you should
//            call FillInAdditionalAttributesInForm() to add and fill in additional attributes.
//            To save changes, call TransferValuesFromFormAttributesToObject();
//            to update the content of attributes, call UpdateAdditionalAttributesItems().
//
//    * CommandBarItemName - String - name of form group to which the button will be added.
//            EditAdditionalAttributesContent. If item name is
//            not specified, then standard group "Form" is used.CommandBar.
//
//    * HideDeleted - Boolean - set/disable the mode of hiding deleted items.
//            If the parameter is not specified but the object is specified and
//            property Reference is not filled, then initial value is set to True, otherwise False.
//            When procedure BeforeWritingOnServer is called in the mode of
//            deleted items hiding, deleted values are cleared (not transferred back to the object) and mode HideDeleted is set to False.
//
Procedure OnCreateAtServer(Form, AdditionalParameters = Undefined,
			Outdated3 = "", Outdated4 = False, Outdated5 = "") Export
	
	Context = New Structure;
	Context.Insert("Object",                     Undefined);
	Context.Insert("ItemNameForPlacement",   "");
	Context.Insert("ArbitraryObject",         False);
	Context.Insert("CommandBarItemName", "");
	Context.Insert("HideDeleted",            Undefined);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(Context, AdditionalParameters);
	Else
		Context.Object                     = AdditionalParameters;
		Context.ItemNameForPlacement   = Outdated3;
		Context.ArbitraryObject         = Outdated4;
		Context.CommandBarItemName = Outdated5;
	EndIf;
	
	If Context.ArbitraryObject Then
		CreateAdditionalAttributesDescription = True;
	Else
		If Context.Object = Undefined Then
			ObjectDescription = Form.Object;
		Else
			ObjectDescription = Context.Object;
		EndIf;
		CreateAdditionalAttributesDescription = UseAdditAttributes(ObjectDescription.Ref);
		If Not ValueIsFilled(ObjectDescription.Ref) AND Context.HideDeleted = Undefined Then
			Context.HideDeleted = True;
		EndIf;
	EndIf;
	
	CreateMainFormObjects(Form, Context.ItemNameForPlacement,
		CreateAdditionalAttributesDescription, Context.CommandBarItemName);
	
	If Not Context.ArbitraryObject Then
		AdditionalAttributesInFormFill(Form, ObjectDescription, , Context.HideDeleted);
	EndIf;
	
EndProcedure

// Fills in the object from attributes created in the form.
// Called from handler BeforeWritingOnServer of object form with properties.
//
// Parameters:
//  Form         - ManagedForm - already configured in procedure OnCreateAtServer.
//  CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	Structure = New Structure("Properties_UseProperties");
	FillPropertyValues(Structure, Form);
	
	If TypeOf(Structure.Properties_UseProperties) = Type("Boolean") Then
		AdditionalAttributesInFormFill(Form, CurrentObject);
	EndIf;
	
EndProcedure

// Fills in the object from attributes created in the form.
// Called from handler BeforeWritingOnServer of object form with properties.
//
// Parameters:
//  Form         - ManagedForm - already configured in procedure OnCreateAtServer.
//  CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	PropertiesManagementService.MoveValuesFromFormAttributesToObject(Form, CurrentObject, True);
	
EndProcedure

// Checks the completion of attributes mandatory for filling.
// 
// Parameters:
//  Form                - ManagedForm - already configured in procedure OnCreateAtServer.
//  Cancel                - Boolean - parameter of handler FillCheckProcessingAtServer.
//  CheckedAttributes - Array - parameter of handler FillCheckProcessingAtServer.
//
Procedure FillCheckProcessing(Form, Cancel, CheckedAttributes) Export
	
	If Not Form.Properties_UseProperties
	 OR Not Form.Properties_UseAdditAttributes Then
		
		Return;
	EndIf;
	
	Errors = Undefined;
	
	For Each String IN Form.Properties_AdditionalAttributesDescription Do
		If String.FillObligatory AND Not String.Deleted Then
			If Not ValueIsFilled(Form[String.AttributeNameValue]) Then
				
				CommonUseClientServer.AddUserError(Errors,
					String.AttributeNameValue,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Field ""%1"" is not filled.';ru='Поле ""%1"" не заполнено.'"), String.Description),
					"");
			EndIf;
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndProcedure

// Updates the sets of additional attributes and information for the kind of objects with properties.
//  Used at writing of catalog items that are the kinds of objects with properties.
//  For example if there is catalog ProductsAndServices to which subsystem Properties
// is applied, then for it catalog ProductsAndServicesKinds is created and you should call this procedure when recording item ProductsAndServicesKind.
//
// Parameters:
//  ObjectKind                - Object - for example, format of products and services before record.
//  ObjectNameWithProperties    - String - for example, Products and services.
//  PropertiesSetAttributeName - String - used when there are several
//                              sets of properties or the name of main set attribute different from "PropertiesSet" is used.
//
Procedure BeforeObjectKindWrite(ObjectKind,
                                  ObjectNameWithProperties,
                                  PropertiesSetAttributeName = "PropertySet") Export
	
	SetPrivilegedMode(True);
	
	PropertySet   = ObjectKind[PropertiesSetAttributeName];
	ParentOfSet = Catalogs.AdditionalAttributesAndInformationSets[ObjectNameWithProperties];
	
	If ValueIsFilled(PropertySet) Then
		
		OldSetProperties = CommonUse.ObjectAttributesValues(
			PropertySet, "Name, Parent, DeletionMark");
		
		If OldSetProperties.Description    = ObjectKind.Description
		   AND OldSetProperties.DeletionMark = ObjectKind.DeletionMark
		   AND OldSetProperties.Parent        = ParentOfSet Then
			
			Return;
		EndIf;
		
		If OldSetProperties.Parent = ParentOfSet Then
			LockDataForEdit(PropertySet);
			PropertiesSetObject = PropertySet.GetObject();
		Else
			PropertiesSetObject = PropertySet.Copy();
		EndIf;
	Else
		PropertiesSetObject = Catalogs.AdditionalAttributesAndInformationSets.CreateItem();
	EndIf;
	
	PropertiesSetObject.Description    = ObjectKind.Description;
	PropertiesSetObject.DeletionMark = ObjectKind.DeletionMark;
	PropertiesSetObject.Parent        = ParentOfSet;
	PropertiesSetObject.Write();
	
	ObjectKind[PropertiesSetAttributeName] = PropertiesSetObject.Ref;
	
	// Update names of uncommon additional attributes and information.
	If Not ValueIsFilled(PropertySet) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("PropertySet", PropertySet);
	Query.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertySet.Description AS NameOfSet,
	|	Properties.PropertySet.DeletionMark AS DeletionMarkSet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|WHERE
	|	Properties.PropertySet = &PropertySet
	|	AND CASE
	|			WHEN Properties.Description <> Properties.Title + "" ("" + Properties.PropertySet.Description + "")""
	|				THEN TRUE
	|			WHEN Properties.DeletionMark <> Properties.PropertySet.DeletionMark
	|				THEN TRUE
	|			ELSE FALSE
	|		END";
	Selection = Query.Execute().Select();
	
	PropertySelection = Query.Execute().Select();
	While PropertySelection.Next() Do
		LockDataForEdit(PropertySelection.Ref);
		Object = PropertySelection.Ref.GetObject();
		Object.Description = Object.Title + " (" + String(PropertySelection.NameOfSet) + ")";
		Object.DeletionMark = PropertySelection.DeletionMarkSet;
		Object.Write();
	EndDo;
	
EndProcedure

// Updates displayed data on object form with properties.
// 
// Parameters:
//  Form           - ManagedForm - already configured in procedure OnCreateAtServer.
//
//  Object          - Undefined - take the object from the "Object" form attribute.
//                  - Object - CatalogObject, DocumentObject, ... , FormDataStructure (by type of object).
//
//  HideDeleted - Undefined - do not change current mode of deleted items hiding which was set earlier.
//                  - Boolean - set/disable the mode of hiding deleted items.
//                    When procedure BeforeWritingOnServer is called in the mode of
//                    deleted items hiding, deleted values are cleared (not transferred back to the object) and mode HideDeleted is set to False.
//
Procedure UpdateAdditionalAttributesItems(Form, Object = Undefined, HideDeleted = Undefined) Export
	
	PropertiesManagementService.MoveValuesFromFormAttributesToObject(Form, Object);
	
	AdditionalAttributesInFormFill(Form, Object, , HideDeleted);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for nonstandard processing of additional properties.

// Creates/recreates additional attributes and items in the form of properties owner.
//
// Parameters:
//  Form           - ManagedForm - already configured in procedure OnCreateAtServer.
//
//  Object          - Undefined - take the object from the "Object" form attribute.
//                  - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by type of object).
//
//  InscriptionFields    - Boolean - if you specify True, then iscription fields will be created in the form instead of input fields.
//
//  HideDeleted - Undefined - do not change current mode of deleted items hiding which was set earlier.
//                  - Boolean - set/disable the mode of hiding deleted items.
//                    When procedure BeforeWritingOnServer is called in the mode of
//                    deleted items hiding, deleted values are cleared (not transferred back to the object) and mode HideDeleted is set to False.
//
Procedure AdditionalAttributesInFormFill(Form, Object = Undefined, InscriptionFields = False, HideDeleted = Undefined) Export
	
	If Not Form.Properties_UseProperties
	 OR Not Form.Properties_UseAdditAttributes Then
		Return;
	EndIf;
	
	If TypeOf(HideDeleted) = Type("Boolean") Then
		Form.Properties_HideDeleted = HideDeleted;
	EndIf;
	
	If Object = Undefined Then
		ObjectDescription = Form.Object;
	Else
		ObjectDescription = Object;
	EndIf;
	
	Form.Properties_AdditionalObjectAttributesSets = New ValueList;
	
	PurposeKey = Undefined;
	ObjectPropertiesSets = PropertiesManagementService.GetObjectPropertiesSets(
		ObjectDescription, PurposeKey);
	
	For Each String IN ObjectPropertiesSets Do
		If PropertiesManagementService.SetPropertyTypes(String.Set).AdditionalAttributes Then
			
			Form.Properties_AdditionalObjectAttributesSets.Add(
				String.Set, String.Title);
		EndIf;
	EndDo;
	
	UpdateFormPurposeKey(Form, PurposeKey);
	
	PropertiesDescription = PropertiesManagementService.GetPropertiesValuesTable(
		ObjectDescription.AdditionalAttributes.Unload(),
		Form.Properties_AdditionalObjectAttributesSets,
		False);
	
	PropertiesDescription.Columns.Add("AttributeNameValue");
	PropertiesDescription.Columns.Add("NameUniquePart");
	PropertiesDescription.Columns.Add("AdditionalValue");
	PropertiesDescription.Columns.Add("Boolean");
	
	DeleteOldAttributesAndItems(Form);
	
	// Creation of attributes.
	AttributesToAdd = New Array();
	For Each PropertyDetails IN PropertiesDescription Do
		
		PropertyValueType = New TypeDescription(PropertyDetails.ValueType,
			,,, New StringQualifiers(1024));
		
		// Supporting rows of unlimited length.
		UseOpenEndedString = PropertiesManagementService.UseOpenEndedString(
			PropertyValueType, PropertyDetails.MultilineTextBox);
		
		If UseOpenEndedString Then
			PropertyValueType = New TypeDescription("String");
		EndIf;
		
		PropertyDetails.NameUniquePart = 
			StrReplace(Upper(String(PropertyDetails.Set.UUID())), "-", "x")
			+ "_"
			+ StrReplace(Upper(String(PropertyDetails.Property.UUID())), "-", "x");
		
		PropertyDetails.AttributeNameValue =
			"AdditionalAttributeValue_" + PropertyDetails.NameUniquePart;
		
		If PropertyDetails.Deleted Then
			PropertyValueType = New TypeDescription("String");
		EndIf;
		
		Attribute = New FormAttribute(PropertyDetails.AttributeNameValue, PropertyValueType, , PropertyDetails.Description, True);
		AttributesToAdd.Add(Attribute);
		
		PropertyDetails.AdditionalValue =
			PropertiesManagementService.ValueTypeContainsPropertiesValues(PropertyValueType);
		
		PropertyDetails.Boolean = CommonUse.TypeDescriptionFullConsistsOfType(PropertyValueType, Type("Boolean"));
	EndDo;
	Form.ChangeAttributes(AttributesToAdd);
	
	// Creating form items.
	ItemNameForPlacement = Form.Properties_ItemNameForPlacement;
	PlacingItem = ?(ItemNameForPlacement = "", Undefined, Form.Items[ItemNameForPlacement]);
	
	For Each PropertyDetails IN PropertiesDescription Do
		
		FormPropertyDescription = Form.Properties_AdditionalAttributesDescription.Add();
		FillPropertyValues(FormPropertyDescription, PropertyDetails);
		
		Form[PropertyDetails.AttributeNameValue] = PropertyDetails.Value;
		
		If PropertyDetails.Deleted AND Form.Properties_HideDeleted Then
			Continue;
		EndIf;
		
		If ObjectPropertiesSets.Count() > 1 Then
			
			ItemOfList = Form.Properties_AdditionalAttributesGroupsItems.FindByValue(
				PropertyDetails.Set);
			
			If ItemOfList <> Undefined Then
				Parent = Form.Items[ItemOfList.Presentation];
			Else
				DescriptionOfSet = ObjectPropertiesSets.Find(PropertyDetails.Set, "Set");
				
				If DescriptionOfSet = Undefined Then
					DescriptionOfSet = ObjectPropertiesSets.Add();
					DescriptionOfSet.Set     = PropertyDetails.Set;
					DescriptionOfSet.Title = NStr("en='Deleted attributes';ru='Удаленные реквизиты'")
				EndIf;
				
				If Not ValueIsFilled(DescriptionOfSet.Title) Then
					DescriptionOfSet.Title = String(PropertyDetails.Set);
				EndIf;
				
				ElementNameSet = "SetOfAdditionalAttributes" + PropertyDetails.NameUniquePart;
				
				Parent = Form.Items.Add(ElementNameSet, Type("FormGroup"), PlacingItem);
				
				Form.Properties_AdditionalAttributesGroupsItems.Add(
					PropertyDetails.Set, Parent.Name);
				
				If TypeOf(PlacingItem) = Type("FormGroup")
				   AND PlacingItem.Type = FormGroupType.Pages Then
					
					Parent.Type = FormGroupType.Page;
				Else
					Parent.Type = FormGroupType.UsualGroup;
					Parent.Representation = UsualGroupRepresentation.None;
				EndIf;
				Parent.ShowTitle = False;
				
				FilledGroupProperties = New Structure;
				For Each Column IN ObjectPropertiesSets.Columns Do
					If DescriptionOfSet[Column.Name] <> Undefined Then
						FilledGroupProperties.Insert(Column.Name, DescriptionOfSet[Column.Name]);
					EndIf;
				EndDo;
				FillPropertyValues(Parent, FilledGroupProperties);
			EndIf;
		Else
			Parent = PlacingItem;
		EndIf;
		
		Item = Form.Items.Add(PropertyDetails.AttributeNameValue, Type("FormField"), Parent);
		FormPropertyDescription.FormItemAdded = True;
		
		If PropertyDetails.Boolean AND IsBlankString(PropertyDetails.FormatProperties) Then
			Item.Type = FormFieldType.CheckBoxField
		Else
			If InscriptionFields Then
				Item.Type = FormFieldType.LabelField;
				Item.Border = New Border(ControlBorderType.Single);
			Else
				Item.Type = FormFieldType.InputField;
				Item.AutoMarkIncomplete = PropertyDetails.FillObligatory AND Not PropertyDetails.Deleted;
			EndIf;
		EndIf;
		
		Item.DataPath = PropertyDetails.AttributeNameValue;
		Item.ToolTip   = PropertyDetails.Property.ToolTip;
		
		If Item.Type = FormFieldType.InputField
		   AND Not UseOpenEndedString
		   AND PropertyDetails.ValueType.Types().Find(Type("String")) <> Undefined Then
			
			Item.TypeLink = New TypeLink("Properties_AdditionalAttributesDescription.Property",
				PropertiesDescription.IndexOf(PropertyDetails));
		EndIf;
		
		If PropertyDetails.Property.MultilineTextBox > 0 Then
			If Not InscriptionFields Then
				Item.MultiLine = True;
			EndIf;
			Item.Height = PropertyDetails.Property.MultilineTextBox;
		EndIf;
		
		If Not IsBlankString(PropertyDetails.FormatProperties) Then
			If InscriptionFields Then
				Item.Format = PropertyDetails.FormatProperties;
			Else
				FormatString = "";
				Array = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
					PropertyDetails.FormatProperties, ";");
				
				For Each Substring IN Array Do
					If Find(Substring, "DP=") > 0 OR Find(Substring, "DE=") > 0 Then
						Continue;
					EndIf;
					If Find(Substring, "NZ=") > 0 OR Find(Substring, "NZ=") > 0 Then
						Continue;
					EndIf;
					If Find(Substring, "DF=") > 0 OR Find(Substring, "DF=") > 0 Then
						If Find(Substring, "ddd") > 0 OR Find(Substring, "ddd") > 0 Then
							Substring = StrReplace(Substring, "ddd", "dd");
							Substring = StrReplace(Substring, "ddd", "dd");
						EndIf;
						If Find(Substring, "dddd") > 0 OR Find(Substring, "dddd") > 0 Then
							Substring = StrReplace(Substring, "dddd", "dd");
							Substring = StrReplace(Substring, "dddd", "dd");
						EndIf;
						If Find(Substring, "MMM") > 0 OR Find(Substring, "MMM") > 0 Then
							Substring = StrReplace(Substring, "MMM", "MM");
							Substring = StrReplace(Substring, "MMM", "MM");
						EndIf;
						If Find(Substring, "MMMM") > 0 OR Find(Substring, "MMMM") > 0 Then
							Substring = StrReplace(Substring, "MMMM", "MM");
							Substring = StrReplace(Substring, "MMMM", "MM");
						EndIf;
					EndIf;
					If Find(Substring, "DLF=") > 0 OR Find(Substring, "DLF=") > 0 Then
						If Find(Substring, "DD") > 0 OR Find(Substring, "DD") > 0 Then
							Substring = StrReplace(Substring, "DD", "D");
							Substring = StrReplace(Substring, "DD", "D");
						EndIf;
					EndIf;
					FormatString = FormatString + ?(FormatString = "", "", ";") + Substring;
				EndDo;
				
				Item.Format = FormatString;
				Item.EditFormat = FormatString;
			EndIf;
		EndIf;
		
		If PropertyDetails.Deleted Then
			Item.TitleTextColor = StyleColors.InaccessibleDataColor;
			Item.TitleFont = StyleFonts.DeletedAdditionalAttributeFont;
			If Item.Type = FormFieldType.InputField Then
				Item.ClearButton = True;
				Item.ChoiceButton = False;
				Item.OpenButton = False;
				Item.DropListButton = False;
				Item.TextEdit = False;
			EndIf;
			
		ElsIf Not InscriptionFields Then
			
			AdditionalValuesTypes = New Map;
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValues"), True);
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValuesHierarchy"), True);
			
			InUseTypeAdditionalValues = True;
			For Each Type IN PropertyDetails.ValueType.Types() Do
				If AdditionalValuesTypes.Get(Type) = Undefined Then
					InUseTypeAdditionalValues = False;
					Break;
				EndIf;
			EndDo;
			If InUseTypeAdditionalValues Then
				Item.OpenButton = False;
			EndIf;
		EndIf;
		
		If Not InscriptionFields AND PropertyDetails.AdditionalValue Then
			ChoiceParameters = New Array;
			ChoiceParameters.Add(New ChoiceParameter("Filter.Owner",
				?(ValueIsFilled(PropertyDetails.AdditionalValuesOwner),
					PropertyDetails.AdditionalValuesOwner, PropertyDetails.Property)));
			Item.ChoiceParameters = New FixedArray(ChoiceParameters);
		EndIf;
		
	EndDo;
	
EndProcedure

// Transfers properties values from form attributes to tabular section of the object.
// 
// Parameters:
//  Form        - ManagedForm - already configured in procedure OnCreateAtServer.
//  Object       - Undefined - take the object from the "Object" form attribute.
//               - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
Procedure MoveValuesFromFormAttributesToObject(Form, Object = Undefined) Export
	
	PropertiesManagementService.MoveValuesFromFormAttributesToObject(Form, Object);
	
EndProcedure

// Deletes old attributes and form items.
// 
// Parameters:
//  Form        - ManagedForm - already configured in procedure OnCreateAtServer.
//  
Procedure DeleteOldAttributesAndItems(Form) Export
	
	AttributesToBeRemoved = New Array;
	For Each PropertyDetails IN Form.Properties_AdditionalAttributesDescription Do
		AttributesToBeRemoved.Add(PropertyDetails.AttributeNameValue);
		If PropertyDetails.FormItemAdded Then
			Form.Items.Delete(Form.Items[PropertyDetails.AttributeNameValue]);
		EndIf;
	EndDo;
	
	If AttributesToBeRemoved.Count() > 0 Then
		Form.ChangeAttributes(, AttributesToBeRemoved);
	EndIf;
	
	For Each ItemOfList IN Form.Properties_AdditionalAttributesGroupsItems Do
		Form.Items.Delete(Form.Items[ItemOfList.Presentation]);
	EndDo;
	
	Form.Properties_AdditionalAttributesDescription.Clear();
	Form.Properties_AdditionalAttributesGroupsItems.Clear();
	
EndProcedure

// Returns owner properties.
//
// Parameters:
//  PropertiesOwner      - Ref - for example, CatalogRef.ProductsAndServices, DocumentRef.CustomerOrder, ...
//  GetAdditAttributes - Boolean - include additional attributes into result.
//  GetAdditInfo  - Boolean - include additional information into result.
//
// Returns:
//  Array - values
//    * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - if any.
//
Function GetListOfProperties(PropertiesOwner, GetAdditAttributes = True, GetAdditInfo = True) Export
	
	If Not (GetAdditAttributes OR GetAdditInfo) Then
		Return New Array;
	EndIf;
	
	ObjectPropertiesSets = PropertiesManagementService.GetObjectPropertiesSets(
		PropertiesOwner);
	
	ObjectPropertiesSetsArray = ObjectPropertiesSets.UnloadColumn("Set");
	
	QueryTextAdditAttributes = 
		"SELECT
		|	PropertyTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS PropertyTable
		|WHERE
		|	PropertyTable.Ref IN (&ObjectPropertiesSetsArray)";
	
	QueryTextAdditInfo = 
		"SELECT ALLOWED
		|	PropertyTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS PropertyTable
		|WHERE
		|	PropertyTable.Ref IN (&ObjectPropertiesSetsArray)";
	
	Query = New Query;
	
	If GetAdditAttributes AND GetAdditInfo Then
		Query.Text = QueryTextAdditInfo +
		"
		| UNION ALL
		|" + QueryTextAdditAttributes;
		
	ElsIf GetAdditAttributes Then
		Query.Text = QueryTextAdditAttributes;
		
	ElsIf GetAdditInfo Then
		Query.Text = QueryTextAdditInfo;
	EndIf;
	
	Query.Parameters.Insert("ObjectPropertiesSetsArray", ObjectPropertiesSetsArray);
	
	Result = Query.Execute().Unload().UnloadColumn("Property");
	
	Return Result;
	
EndFunction

// Returns the values of additional object properties.
//
// Parameters:
//  PropertiesOwner      - Ref - for example, CatalogRef.ProductsAndServices, DocumentRef.CustomerOrder, ...
//  GetAdditAttributes - Boolean - include additional attributes into result.
//  GetAdditInfo  - Boolean - include additional information into result.
//  PropertyArray        - Array - properties:
//                          * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - values
//                            of which shall be received.
//                       - Undefined - receive values of all properties of the owner.
// Returns:
//  ValueTable - Columns:
//    Group unable to set property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - owner property.
//    * Value - Arbitrary - values of any type from the description of metadata object property types:
//                  "Metadata.ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.Type".
//
Function GetValuesOfProperties(PropertiesOwner,
                                GetAdditAttributes = True,
                                GetAdditInfo = True,
                                PropertyArray = Undefined) Export
	
	If PropertyArray = Undefined Then
		PropertyArray = GetListOfProperties(PropertiesOwner, GetAdditAttributes, GetAdditInfo);
	EndIf;
	
	ObjectNameWithProperties = CommonUse.TableNameByRef(PropertiesOwner);
	
	QueryTextAdditAttributes =
		"SELECT [ALLOWED]
		|	PropertyTable.Property AS Property,
		|	PropertyTable.Value AS Value,
		|	CASE
		|		WHEN AdditionalAttributesAndInformation.MultilineTextBox > 0
		|			THEN PropertyTable.TextString
		|		ELSE """"
		|	END AS TextString
		|FROM
		|	[ObjectNameWithProperties].AdditionalAttributes AS PropertyTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
		|		ON PropertyTable.Property = AdditionalAttributesAndInformation.Ref
		|WHERE
		|	PropertyTable.Ref = &PropertiesOwner
		|	AND PropertyTable.Property IN (&PropertyArray)";
	
	QueryTextAdditInfo =
		"SELECT [ALLOWED]
		|	PropertyTable.Property AS Property,
		|	PropertyTable.Value AS Value,
		|	"""" AS TextString
		|FROM
		|	InformationRegister.AdditionalInformation AS PropertyTable
		|WHERE
		|	PropertyTable.Object = &PropertiesOwner
		|	AND PropertyTable.Property IN (&PropertyArray)";
	
	Query = New Query;
	
	If GetAdditAttributes AND GetAdditInfo Then
		QueryText = StrReplace(QueryTextAdditAttributes, "[ALLOWED]", "ALLOWED") +
			"
			| UNION ALL
			|" + StrReplace(QueryTextAdditInfo, "[ALLOWED]", "");
		
	ElsIf GetAdditAttributes Then
		QueryText = StrReplace(QueryTextAdditAttributes, "[ALLOWED]", "ALLOWED");
		
	ElsIf GetAdditInfo Then
		QueryText = StrReplace(QueryTextAdditInfo, "[ALLOWED]", "ALLOWED");
	EndIf;
	
	QueryText = StrReplace(QueryText, "[ObjectWithPropertiesName]", ObjectNameWithProperties);
	
	Query.Parameters.Insert("PropertiesOwner", PropertiesOwner);
	Query.Parameters.Insert("PropertyArray", PropertyArray);
	Query.Text = QueryText;
	
	Result = Query.Execute().Unload();
	ResultWithTextStrings = Undefined;
	RowIndex = 0;
	For Each PropertyValue IN Result Do
		TextString = PropertyValue.TextString;
		If Not IsBlankString(TextString) Then
			If ResultWithTextStrings = Undefined Then
				ResultWithTextStrings = Result.Copy(,"Property");
				ResultWithTextStrings.Columns.Add("Value");
				ResultWithTextStrings.LoadColumn(Result.UnloadColumn("Value"), "Value");
			EndIf;
			ResultWithTextStrings[RowIndex].Value = TextString;
		EndIf;
		RowIndex = RowIndex + 1;
	EndDo;
	
	Return ?(ResultWithTextStrings <> Undefined, ResultWithTextStrings, Result);
	
EndFunction

// Checks if the object has a property.
//
// Parameters:
//  PropertiesOwner - Ref - for example, CatalogRef.ProductsAndServices, DocumentRef.CustomerOrder, ...
//  Property        - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - checked property.
//
// Returns:
//  Boolean - if True, the owner has a property.
//
Function CheckObjectProperty(PropertiesOwner, Property) Export
	
	PropertyArray = GetListOfProperties(PropertiesOwner);
	
	If PropertyArray.Find(Property) = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns enumerated values of specified property.
// 
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - property
//             for which you need to receive enumerated values.
// 
// Returns:
//  Array - values:
//    * CatalogReference.ObjectPropertiesValues, CatalogReference.ObjectsPropertiesValuesHierarchy - property
//      values if any.
//
Function GetListOfValuesOfProperties(Property) Export
	
	ValueType = CommonUse.ObjectAttributeValue(Property, "ValueType");
	
	If ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValuesHierarchy AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner = &Property";
	Else
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner = &Property";
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Property", Property);
	Result = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

// Writes additional attributes and information for properties owner.
// Changes occur in the transaction.
// 
// Parameters:
//  PropertiesOwner - Ref - for example, CatalogRef.ProductsAndServices, DocumentRef.CustomerOrder, ...
//  PropertiesAndValuesTable - ValueTable - with columns:
//    Group unable to set property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation - owner property.
//    * Value - Arbitrary - any value acceptable for the property (specified in property item).
//
Procedure WriteObjectProperties(PropertiesOwner, PropertiesAndValuesTable) Export
	
	AdditAttributesTable = New ValueTable;
	AdditAttributesTable.Columns.Add("Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"));
	AdditAttributesTable.Columns.Add("Value");
	
	AdditInfoTable = AdditAttributesTable.CopyColumns();
	
	For Each PropertiesTableRow IN PropertiesAndValuesTable Do
		If PropertiesTableRow.Property.ThisIsAdditionalInformation Then
			NewRow = AdditInfoTable.Add();
		Else
			NewRow = AdditAttributesTable.Add();
		EndIf;
		FillPropertyValues(NewRow, PropertiesTableRow, "Property,Value");
	EndDo;
	
	AreAdditAttributes = AdditAttributesTable.Count() > 0;
	IsAdditInfo  = AdditInfoTable.Count() > 0;
	
	PropertyArray = GetListOfProperties(PropertiesOwner);
	
	AdditAttributesArray = New Array;
	ArrayAddInformation = New Array;
	
	For Each AdditionalProperty IN PropertyArray Do
		If AdditionalProperty.ThisIsAdditionalInformation Then
			ArrayAddInformation.Add(AdditionalProperty);
		Else
			AdditAttributesArray.Add(AdditionalProperty);
		EndIf;
	EndDo;
	
	BeginTransaction(DataLockControlMode.Managed);
	
	If AreAdditAttributes Then
		OwnerOfObjectProperties = PropertiesOwner.GetObject();
		LockDataForEdit(OwnerOfObjectProperties.Ref);
		For Each AdditionalAttribute IN AdditAttributesTable Do
			If AdditAttributesArray.Find(AdditionalAttribute.Property) = Undefined Then
				Continue;
			EndIf;
			RowArray = OwnerOfObjectProperties.AdditionalAttributes.FindRows(New Structure("Property", AdditionalAttribute.Property));
			If RowArray.Count() Then
				PropertyString = RowArray[0];
			Else
				PropertyString = OwnerOfObjectProperties.AdditionalAttributes.Add();
			EndIf;
			FillPropertyValues(PropertyString, AdditionalAttribute, "Property,Value");
		EndDo;
		OwnerOfObjectProperties.Write();
	EndIf;
	
	If IsAdditInfo Then
		For Each AdditInfo IN AdditInfoTable Do
			If ArrayAddInformation.Find(AdditInfo.Property) = Undefined Then
				Continue;
			EndIf;
			
			RecordManager = InformationRegisters.AdditionalInformation.CreateRecordManager();
			
			RecordManager.Object = PropertiesOwner;
			RecordManager.Property = AdditInfo.Property;
			RecordManager.Value = AdditInfo.Value;
			
			RecordManager.Write(True);
		EndDo;
		
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// Checks if additional attributes with object are used.
//
// Parameters:
//  PropertiesOwner - Ref - for example, CatalogReference.ProductsAndServices, DocumentReference.CustomerOrder, ...
//
// Returns:
//  Boolean - if True, then additional attributes are used.
//
Function UseAdditAttributes(PropertiesOwner) Export
	
	OwnerMetadata = PropertiesOwner.Metadata();
	Return OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined
	      AND OwnerMetadata <> Metadata.Catalogs.AdditionalAttributesAndInformationSets;
	
EndFunction

// Checks if the object is used by additional information.
//
// Parameters:
//  PropertiesOwner - Ref - for example, CatalogReference.ProductsAndServices, DocumentReference.CustomerOrder, ...
//
// Returns:
//  Boolean - if True, then additional information is used.
//
Function UseAdditInfo(PropertiesOwner) Export
	
	Return Metadata.FindByFullName("CommonCommand.AdditionalInformationCommandBar") <> Undefined
	      AND Metadata.CommonCommands.AdditionalInformationCommandBar.CommandParameterType.Types().Find(TypeOf(PropertiesOwner)) <> Undefined
	    OR Metadata.FindByFullName("CommonCommand.AdditionalInformationNavigationPanel") <> Undefined
	      AND Metadata.CommonCommands.AdditionalInformationNavigationPanel.CommandParameterType.Types().Find(TypeOf(PropertiesOwner)) <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// 1. Updates the names of
// predefined sets of properties if they differ
// from current presentation of corresponding metadata objects with properties.
// 2. Updates the names of uncommon properties,
// if their clarification is different from the name of their set.
// 3. Sets deletion mark for uncommon
// properties if there is a deletion mark for their sets.
//
Procedure UpdateSetsAndPropertiesNames() Export
	
	QuerySets = New Query;
	QuerySets.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.Description AS Description
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets AS Sets
	|WHERE
	|	Sets.Predefined
	|	AND Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInformationSets.EmptyRef)";
	
	SelectionSets = QuerySets.Execute().Select();
	While SelectionSets.Next() Do
		
		Description = PropertiesManagementService.DescriptionPredefinedSet(
			SelectionSets.Ref);
		
		If SelectionSets.Description <> Description Then
			Object = SelectionSets.Ref.GetObject();
			Object.Description = Description;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
	QueryProperties = New Query;
	QueryProperties.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertySet.Description AS NameOfSet,
	|	Properties.PropertySet.DeletionMark AS DeletionMarkSet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|WHERE
	|	CASE
	|			WHEN Properties.PropertySet = VALUE(Catalog.AdditionalAttributesAndInformationSets.EmptyRef)
	|				THEN FALSE
	|			ELSE CASE
	|					WHEN Properties.Description <> Properties.Title + "" ("" + Properties.PropertySet.Description + "")""
	|						THEN TRUE
	|					WHEN Properties.DeletionMark <> Properties.PropertySet.DeletionMark
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END";
	
	PropertySelection = QueryProperties.Execute().Select();
	While PropertySelection.Next() Do
		
		Object = PropertySelection.Ref.GetObject();
		Object.Description = Object.Title + " (" + String(PropertySelection.NameOfSet) + ")";
		Object.DeletionMark = PropertySelection.DeletionMarkSet;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Creates basic attributes, commands, items in the form of properties owner.
Procedure CreateMainFormObjects(Form, ItemNameForPlacement,
		CreateAdditionalAttributesDescription, CommandBarItemName)
	
	Attributes = New Array;
	
	// Checking the values of functional option "Properties use".
	OptionUseProperties = Form.GetFormFunctionalOption("UseAdditionalAttributesAndInformation");
	AttributeUseProperties = New FormAttribute("Properties_UseProperties", New TypeDescription("Boolean"));
	Attributes.Add(AttributeUseProperties);
	AttributeHideDeleted = New FormAttribute("Properties_HideDeleted", New TypeDescription("Boolean"));
	Attributes.Add(AttributeHideDeleted);
	
	If OptionUseProperties Then
		
		AttributeUseAdditAttributes = New FormAttribute("Properties_UseAdditAttributes", New TypeDescription("Boolean"));
		Attributes.Add(AttributeUseAdditAttributes);
		
		If CreateAdditionalAttributesDescription Then
			
			// Adding the attribute containing used sets of additional attributes.
			Attributes.Add(New FormAttribute(
				"Properties_AdditionalObjectAttributesSets", New TypeDescription("ValueList")));
			
			// Adding the attribute of description of created attributes and item forms.
			DescriptionName = "Properties_AdditionalAttributesDescription";
			
			Attributes.Add(New FormAttribute(
				DescriptionName, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"AttributeNameValue", New TypeDescription("String"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"),
					DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"ValueType", New TypeDescription("TypeDescription"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"MultilineTextBox", New TypeDescription("Number"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Deleted", New TypeDescription("Boolean"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"FillObligatory", New TypeDescription("Boolean"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"Description", New TypeDescription("String"), DescriptionName));
			
			Attributes.Add(New FormAttribute(
				"FormItemAdded", New TypeDescription("Boolean"), DescriptionName));
			
			// Adding the attribute containing the items of created groups of additional attributes.
			Attributes.Add(New FormAttribute(
				"Properties_AdditionalAttributesGroupsItems", New TypeDescription("ValueList")));
			
			// Adding the attribute with item name in which input fields will be placed.
			Attributes.Add(New FormAttribute(
				"Properties_ItemNameForPlacement", New TypeDescription("String")));
			
			// Addition of form command if role "BasicReferenceDataAdditionChange" is set or this is a full user.
			If Users.RolesAvailable("AddChangeBasicReferenceData") Then
				// Addition of a command.
				Command = Form.Commands.Add("EditAdditionalAttributesContent");
				Command.Title = NStr("en='Change the additional attributes structure';ru='Изменить состав дополнительных реквизитов'");
				Command.Action = "Attachable_EditContentOfProperties";
				Command.ToolTip = NStr("en='Change the additional attributes structure';ru='Изменить состав дополнительных реквизитов'");
				Command.Picture = PictureLib.ListSettings;
				
				Button = Form.Items.Add(
					"EditAdditionalAttributesContent",
					Type("FormButton"),
					?(CommandBarItemName = "",
						Form.CommandBar,
						Form.Items[CommandBarItemName]));
				
				Button.OnlyInAllActions = True;
				Button.CommandName = "EditAdditionalAttributesContent";
			EndIf;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(Attributes);
	
	Form.Properties_UseProperties = OptionUseProperties;
	
	If OptionUseProperties Then
		Form.Properties_UseAdditAttributes = CreateAdditionalAttributesDescription;
	EndIf;
	
	If OptionUseProperties AND CreateAdditionalAttributesDescription Then
		Form.Properties_ItemNameForPlacement = ItemNameForPlacement;
	EndIf;
	
EndProcedure

Procedure UpdateFormPurposeKey(Form, PurposeKey)
	
	If PurposeKey = Undefined Then
		PurposeKey = PropertiesSetsKey(Form.Properties_AdditionalObjectAttributesSets);
	EndIf;
	
	If IsBlankString(PurposeKey) Then
		Return;
	EndIf;
	
	KeyBeginning = "PropertiesSetsKey";
	PropertiesSetsKey = KeyBeginning + Left(PurposeKey + "00000000000000000000000000000000", 32);
	
	NewKey = NewPurposeKey(Form.PurposeUseKey, KeyBeginning, PropertiesSetsKey);
	If NewKey = Undefined Then
		// Key is already complemented.
		NewKey = Form.PurposeUseKey;
	EndIf;
	
	NewPositionKey = NewPurposeKey(Form.WindowOptionsKey, KeyBeginning, PropertiesSetsKey);
	If NewPositionKey = Undefined Then
		// Key is already complemented.
		NewPositionKey = Form.WindowOptionsKey;
	EndIf;
	
	StandardSubsystemsServer.SetFormPurposeKey(Form, NewKey, NewPositionKey);
	
EndProcedure

Function NewPurposeKey(CurrentKey, KeyBeginning, PropertiesSetsKey)
	
	Position = Find(CurrentKey, KeyBeginning);
	
	NewPurposeKey = Undefined;
	
	If Position = 0 Then
		NewPurposeKey = CurrentKey + PropertiesSetsKey;
	
	ElsIf Find(CurrentKey, PropertiesSetsKey) = 0 Then
		NewPurposeKey = Left(CurrentKey, Position - 1) + PropertiesSetsKey
			+ Mid(CurrentKey, Position + StrLen(KeyBeginning) + 32);
	EndIf;
	
	Return NewPurposeKey;
	
EndFunction

Function PropertiesSetsKey(Sets)
	
	SetsIdentifiers = New ValueList;
	
	For Each ItemOfList IN Sets Do
		SetsIdentifiers.Add(String(ItemOfList.Value.UUID()));
	EndDo;
	
	SetsIdentifiers.SortByValue();
	IdentifiersRow = "";
	
	For Each ItemOfList IN SetsIdentifiers Do
		IdentifiersRow = IdentifiersRow + StrReplace(ItemOfList.Value, "-", "");
	EndDo;
	
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(IdentifiersRow);
	
	Return StrReplace(DataHashing.HashSum, " ", "");
	
EndFunction

#EndRegion
