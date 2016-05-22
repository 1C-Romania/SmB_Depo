////////////////////////////////////////////////////////////////////////////////
// Subsystem "Prohibition of object attributes editing"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Takes the object form as a parameter connected
// to the subsystem, and prohibits
// the editing of preset attributes, also it adds the edit permission command into "All actions".
//
// Parameters:
//  Form                   - ManagedForm - object form.
//  GroupForProhibitionButton  - FormGroup - overrides the
//                            default placement of prohibition button on the object form.
//  ProhibitionButtonTitle  - String - button title. By default, "Allow attributes editing".
//  Object                  - Undefined - take the object from the "Object" form attribute.
//                          - FormDataStructure - by object type.
//
Procedure LockAttributes(Form, GroupForProhibitionButton = Undefined, ProhibitionButtonTitle = "",
		Object = Undefined) Export
	
	ObjectDescription = ?(Object = Undefined, Form.Object, Object);
	
	// Definition, form is already prepared on the previous call.
	FormPrepared = False;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute IN FormAttributes Do
		If FormAttribute.Name = "AttributesEditProhibitionParameters" Then
			FormPrepared = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FormPrepared Then
		PrepareForm(Form, ObjectDescription.Ref, GroupForProhibitionButton, ProhibitionButtonTitle);
	EndIf;
	
	IsNewObject = ObjectDescription.Ref.IsEmpty();
	
	// Locking the editing of form items associated with the given attributes.
	For Each DescriptionOfBlockedAttribute IN Form.AttributesEditProhibitionParameters Do
		For Each FormItemDescription IN DescriptionOfBlockedAttribute.BlockedItems Do
			
			DescriptionOfBlockedAttribute.EditAllowed =
				DescriptionOfBlockedAttribute.EditingRight AND IsNewObject;
			
			FormItem = Form.Items.Find(FormItemDescription.Value);
			If FormItem <> Undefined Then
				If TypeOf(FormItem) = Type("FormField")
				 OR TypeOf(FormItem) = Type("FormTable") Then
					FormItem.ReadOnly = Not DescriptionOfBlockedAttribute.EditAllowed;
				Else
					FormItem.Enabled = DescriptionOfBlockedAttribute.EditAllowed;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If Form.Items.Find("AuthorizeObjectDetailsEditing") <> Undefined Then
		Form.Items.AuthorizeObjectDetailsEditing.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Configures the object form for subsystem work:
// - adds the AttributesEditProhibitionParameters attribute to store internal data
// - adds command and the AllowObjectAttributesEditing button (if allowed).
//
Procedure PrepareForm(Form, Refs, GroupForProhibitionButton, ProhibitionButtonTitle)
	
	TypeDescriptionString100 = New TypeDescription("String",,New StringQualifiers(100));
	TypeDescriptionBoolean = New TypeDescription("Boolean");
	TypeDescriptionArray = New TypeDescription("ValueList");
	
	FormAttributes = New Map;
	For Each FormAttribute IN Form.GetAttributes() Do
		FormAttributes.Insert(FormAttribute.Name, FormAttribute.Title);
	EndDo;
	
	// Addition of attributes to a form.
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute("AttributesEditProhibitionParameters", New TypeDescription("ValueTable")));
	AttributesToAdd.Add(New FormAttribute("AttributeName",            TypeDescriptionString100, "AttributesEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("Presentation",           TypeDescriptionString100, "AttributesEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("EditAllowed", TypeDescriptionBoolean,    "AttributesEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("BlockedItems",     TypeDescriptionArray,    "AttributesEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("EditingRight",     TypeDescriptionBoolean,    "AttributesEditProhibitionParameters"));
	
	Form.ChangeAttributes(AttributesToAdd);
	
	AttributesToLock = CommonUse.ObjectManagerByRef(Refs).GetObjectAttributesBeingLocked();
	AllAttributesWithoutEditingRight = True;
	
	For Each LockAttribute IN AttributesToLock Do
		
		AttributeFullName = Form.AttributesEditProhibitionParameters.Add();
		
		PROCInformation = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(LockAttribute, ";");
		AttributeFullName.AttributeName = PROCInformation[0];
		
		If PROCInformation.Count() > 1 Then
			BlockedItems = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PROCInformation[1], ",");
			For Each BlockedItem IN BlockedItems Do
				AttributeFullName.BlockedItems.Add(TrimAll(BlockedItem));
			EndDo;
		EndIf;
		
		FillRelatedItems(AttributeFullName.BlockedItems, Form, AttributeFullName.AttributeName);
		
		ObjectMetadata = Refs.Metadata();
		MetadataOfAttributeOrTabularSection = ObjectMetadata.Attributes.Find(AttributeFullName.AttributeName);
		StandardAttributeOrTabularSection = False;
		If MetadataOfAttributeOrTabularSection = Undefined Then
			MetadataOfAttributeOrTabularSection = ObjectMetadata.TabularSections.Find(AttributeFullName.AttributeName);
			If MetadataOfAttributeOrTabularSection = Undefined Then
				If CommonUse.ThisIsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeFullName.AttributeName) Then
					MetadataOfAttributeOrTabularSection = ObjectMetadata.StandardAttributes[AttributeFullName.AttributeName];
					StandardAttributeOrTabularSection = True;
				EndIf;
			EndIf;
		EndIf;
		
		If MetadataOfAttributeOrTabularSection = Undefined Then
			AttributeFullName.Presentation = FormAttributes[AttributeFullName.AttributeName];
			
			AttributeFullName.EditingRight = True;
			AllAttributesWithoutEditingRight = False;
		Else
			AttributeFullName.Presentation = ?(
				ValueIsFilled(MetadataOfAttributeOrTabularSection.Synonym),
				MetadataOfAttributeOrTabularSection.Synonym,
				MetadataOfAttributeOrTabularSection.Name);
			
			If StandardAttributeOrTabularSection Then
				EditingRight = AccessRight("Edit", ObjectMetadata, , MetadataOfAttributeOrTabularSection.Name);
			Else
				EditingRight = AccessRight("Edit", MetadataOfAttributeOrTabularSection);
			EndIf;
			If EditingRight Then
				AttributeFullName.EditingRight = True;
				AllAttributesWithoutEditingRight = False;
			EndIf;
		EndIf;
	EndDo;
	
	// Addition of command and button if allowed.
	If Users.RolesAvailable("EditObjectAttributes")
	   AND AccessRight("Edit", Refs.Metadata())
	   AND Not AllAttributesWithoutEditingRight Then
		
		// Addition of a command
		Command = Form.Commands.Add("AuthorizeObjectDetailsEditing");
		Command.Title = ?(IsBlankString(ProhibitionButtonTitle), NStr("en = 'Allow Attributes Editing'"), ProhibitionButtonTitle);
		Command.Action = "Attachable_AuthorizeObjectAttributesEditing";
		Command.Picture = PictureLib.AuthorizeObjectDetailsEditing;
		Command.ModifiesStoredData = True;
		
		// Addition of a button
		ParentGroup = ?(GroupForProhibitionButton <> Undefined, GroupForProhibitionButton, Form.CommandBar);
		Button = Form.Items.Add("AuthorizeObjectDetailsEditing", Type("FormButton"), ParentGroup);
		Button.OnlyInAllActions = True;
		Button.CommandName = "AuthorizeObjectDetailsEditing";
	EndIf;
	
EndProcedure

// Returns the form item name from the object attribute name that refers to this item.
Procedure FillRelatedItems(LinkedItemsArray, Form, AttributeName)
	
	For Each FormItem IN Form.Items Do
		If (TypeOf(FormItem) = Type("FormField") AND FormItem.Type <> FormFieldType.LabelField)
			OR TypeOf(FormItem) = Type("FormTable") Then
			DecomposedDataPath = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FormItem.DataPath, ".");
			If DecomposedDataPath.Count() = 2 AND DecomposedDataPath[1] = AttributeName Then
				LinkedItemsArray.Add(FormItem.Name);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
