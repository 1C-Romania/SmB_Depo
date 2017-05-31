Procedure WrireAdditionalAttributeValues(DataObject) Export
	
	If DataObject.AdditionalProperties.Property("AdditionalAttributeValues") then
		For Each AdditionalAttribute In DataObject.AdditionalProperties.AdditionalAttributeValues Do
			RegRecord = InformationRegisters.AdditionalAttributeValues.CreateRecordManager();
			RegRecord.Attribute = Catalogs.AdditionalAttributes.FindByDescription(AdditionalAttribute.Key);
			RegRecord.DataRef = DataObject.Ref;
			RegRecord.Value = AdditionalAttribute.Value;
			RegRecord.Write(True);
		EndDo;
	EndIf;
	
EndProcedure

Procedure PutAddititionalAttributesOnForm(Form) Export
	
	AttributesFormGroup = Undefined;
	If Form.Items.Find("Pages")<>Undefined then
		//Use pages group "Pages"
		If Form.Items.Pages.Type = FormGroupType.Pages then
			AttributesFormGroup = Form.Items.Add("GroupAdditionalAttributes",Type("FormGroup"),Form.Items.Pages);
			AttributesFormGroup.Type = FormGroupType.Page;
			AttributesFormGroup.Title = NStr("en='Additional attributes';pl='Dodatkowe atrybuty';ru='Дополнительные атрибуты'");
		EndIf;
	ElsIf Form.Items.Find("GroupPages")<>Undefined then
		//Use pages group "GroupPages"
		If Form.Items.GroupPages.Type = FormGroupType.Pages then
			AttributesFormGroup = Form.Items.Add("GroupAdditionalAttributes",Type("FormGroup"),Form.Items.GroupPages);
			AttributesFormGroup.Type = FormGroupType.Page;
			AttributesFormGroup.Title = NStr("en='Additional attributes';pl='Dodatkowe atrybuty';ru='Дополнительные атрибуты'");
		EndIf;
	Else
		//Find other pages group on form
		PagesCount = 0;
		PageGroupName = "";
		For Each FormItem In Form.Items Do
			If TypeOf(FormItem)=Type("FormGroup") and FormItem.Type = FormGroupType.Pages then
			   PageGroupName = FormItem.Name;
			   PagesCount = PagesCount + 1;
			EndIf;   
		EndDo; 
		
		If PagesCount=1 then
			//Use found pages group, but if pages count = 1
			AttributesFormGroup = Form.Items.Add("GroupAdditionalAttributes",Type("FormGroup"),Form.Items[PageGroupName]);
			AttributesFormGroup.Type = FormGroupType.Page;
			AttributesFormGroup.Title = NStr("en='Additional attributes';pl='Dodatkowe atrybuty';ru='Дополнительные атрибуты'");
		Else
			//Add new usual group
			AttributesFormGroup = Form.Items.Find("GroupAdditionalAttributes");
			If AttributesFormGroup = Undefined Then
				AttributesFormGroup = Form.Items.Add("GroupAdditionalAttributes",Type("FormGroup"),Form);
				AttributesFormGroup.Type = FormGroupType.UsualGroup;
				AttributesFormGroup.Behavior = UsualGroupBehavior.Collapsible;
				//AttributesFormGroup.Collapsed = True; //It does not work
				AttributesFormGroup.Title = NStr("en='Additional attributes';pl='Dodatkowe atrybuty';ru='Дополнительные атрибуты'");
			EndIf;
		EndIf;	
	EndIf;	
	
	//Get empty value of form object
	ArrayTypes = New Array;
	ArrayTypes.Add(TypeOf(Form.Object.Ref));
	AttributeTypeDescription = New TypeDescription(ArrayTypes);
	EmptyTypeValue = AttributeTypeDescription.AdjustValue();

	//Get additional attributes and values for form object
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributeUsages.Attribute,
	|	AdditionalAttributeUsages.Attribute.AttributeValueType
	|INTO TT_AdditAttributes
	|FROM
	|	InformationRegister.AdditionalAttributeUsages AS AdditionalAttributeUsages
	|WHERE
	|	AdditionalAttributeUsages.DataType = &DataType
	|	AND NOT AdditionalAttributeUsages.Attribute.DeletionMark
	|	AND NOT AdditionalAttributeUsages.Attribute.Hide
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalAttributeValues.Attribute,
	|	AdditionalAttributeValues.Value
	|INTO TT_AdditValues
	|FROM
	|	InformationRegister.AdditionalAttributeValues AS AdditionalAttributeValues
	|WHERE
	|	AdditionalAttributeValues.DataRef = &DataRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_AdditAttributes.Attribute,
	|	ISNULL(TT_AdditValues.Value, TT_AdditAttributes.AttributeAttributeValueType) AS Value
	|FROM
	|	TT_AdditAttributes AS TT_AdditAttributes
	|		LEFT JOIN TT_AdditValues AS TT_AdditValues
	|		ON TT_AdditAttributes.Attribute = TT_AdditValues.Attribute";
	
	Query.SetParameter("DataRef", Form.Object.Ref);
	Query.SetParameter("DataType", EmptyTypeValue);
	
	QuerySelection = Query.Execute().Select();
	
	FormAttributesArray = New Array;
	FormAttributeNames = New Structure;
		
	While QuerySelection.Next() Do
		//Add attribute to form
						
		ArrayValTypes = New Array;
		ArrayValTypes.Add(TypeOf(QuerySelection.Value));
		
		If TypeOf(QuerySelection.Value) = Type("Number") Then
			AttributeValTypeDescription = New TypeDescription(ArrayValTypes, New NumberQualifiers(QuerySelection.Attribute.Digits, QuerySelection.Attribute.FractionDigits, ?(QuerySelection.Attribute.Nonnegative, AllowedSign.Nonnegative, AllowedSign.Any)));
		ElsIf TypeOf(QuerySelection.Value) = Type("Date") Then
			If QuerySelection.Attribute.UseDate And Not QuerySelection.Attribute.UseTime Then
				AttributeValTypeDescription = New TypeDescription(ArrayValTypes,,, New DateQualifiers(DateFractions.Date));
			ElsIf Not QuerySelection.Attribute.UseDate And QuerySelection.Attribute.UseTime Then
				AttributeValTypeDescription = New TypeDescription(ArrayValTypes,,, New DateQualifiers(DateFractions.Time));
			Else
				AttributeValTypeDescription = New TypeDescription(ArrayValTypes,,, New DateQualifiers(DateFractions.DateTime));
			EndIf;
		Else	
			AttributeValTypeDescription = New TypeDescription(ArrayValTypes);
		EndIf;
		
		NewAttribute = New FormAttribute("AA_"+QuerySelection.Attribute.Description, AttributeValTypeDescription, , QuerySelection.Attribute.DescriptionFull, True);
		
		FormAttributesArray.Add(NewAttribute);
		
		FormAttributeNames.Insert("AA_"+QuerySelection.Attribute.Description, QuerySelection.Attribute); 
			
	EndDo; 
	
	//Add additional attribute list
	ArrayValTypes = New Array;
	ArrayValTypes.Add(Type("ValueList"));
	AttributeValTypeDescription = New TypeDescription(ArrayValTypes);
	NewAttribute = New FormAttribute("AdditionalAttributesList", AttributeValTypeDescription,,,False);
	FormAttributesArray.Add(NewAttribute);
	
	//Save output form group in parameter
	ArrayValTypes = New Array;
	ArrayValTypes.Add(Type("String"));
	AttributeValTypeDescription = New TypeDescription(ArrayValTypes);
	NewAttribute = New FormAttribute("AdditionalAttributesOutputGroupName", AttributeValTypeDescription,,,False);
	FormAttributesArray.Add(NewAttribute);
	
	If FormAttributesArray.Count()>0 then 
		Form.ChangeAttributes(FormAttributesArray);
		AdditionalParametersList = New Array;
		
		For Each FormAttribute In FormAttributesArray Do
			If FormAttribute.Name = "AdditionalAttributesList" OR FormAttribute.Name = "AdditionalAttributesOutputGroupName" then
				Continue;
			EndIf;
			
			//Add input fields to form
			NewField = Form.Items.Add(FormAttribute.Name, Type("FormField"), AttributesFormGroup);
			NewField.DataPath = FormAttribute.Name;
									
			If FormAttribute.ValueType.ContainsType(Type("Boolean")) then
				NewField.Type = FormFieldType.CheckBoxField;
			Else
				NewField.Type = FormFieldType.InputField;
				NewField.AvailableTypes = FormAttribute.ValueType;
				
				If NewField.AvailableTypes.ContainsType(Type("CatalogRef.AdditionalAttributeValues")) then
					FilterParameter = New ChoiceParameter("Filter.Owner", FormAttributeNames[FormAttribute.Name]);
					TempArray = New Array();
					TempArray.Add(FilterParameter);
					TempFixedArray = New FixedArray(TempArray);
					NewField.ChoiceParameters = TempFixedArray;
				EndIf;
			EndIf;
									
			Form.AdditionalAttributesList.Add(FormAttribute.Name,Mid(FormAttribute.Name,4));
		EndDo; 
		
		QuerySelection.Reset();
		
	    //Set attribute values on form
		While QuerySelection.Next() Do
			Form["AA_"+QuerySelection.Attribute.Description] = QuerySelection.Value; 
		EndDo; 
	EndIf;
	
	Form.AdditionalAttributesOutputGroupName = AttributesFormGroup.Name;
	
EndProcedure

Procedure PutUpdateAddititionalAttributesOnForm(Form) Export
	
	AttributesFormGroup = Form.Items.Find(Form.AdditionalAttributesOutputGroupName);
	
	//Get empty value of form object
	ArrayTypes = New Array;
	ArrayTypes.Add(TypeOf(Form.Object.Ref));
	AttributeTypeDescription = New TypeDescription(ArrayTypes);
	EmptyTypeValue = AttributeTypeDescription.AdjustValue();

	//Get additional attributes and values for form object
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributeUsages.Attribute,
	|	AdditionalAttributeUsages.Attribute.AttributeValueType,
	|	AdditionalAttributeUsages.Attribute.Hide
	|INTO TT_AdditAttributes
	|FROM
	|	InformationRegister.AdditionalAttributeUsages AS AdditionalAttributeUsages
	|WHERE
	|	AdditionalAttributeUsages.DataType = &DataType
	|	AND NOT AdditionalAttributeUsages.Attribute.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalAttributeValues.Attribute,
	|	AdditionalAttributeValues.Value
	|INTO TT_AdditValues
	|FROM
	|	InformationRegister.AdditionalAttributeValues AS AdditionalAttributeValues
	|WHERE
	|	AdditionalAttributeValues.DataRef = &DataRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_AdditAttributes.Attribute,
	|	ISNULL(TT_AdditValues.Value, TT_AdditAttributes.AttributeAttributeValueType) AS Value,
	|	TT_AdditAttributes.AttributeHide AS Hide
	|FROM
	|	TT_AdditAttributes AS TT_AdditAttributes
	|		LEFT JOIN TT_AdditValues AS TT_AdditValues
	|		ON TT_AdditAttributes.Attribute = TT_AdditValues.Attribute";
	
	Query.SetParameter("DataRef", Form.Object.Ref);
	Query.SetParameter("DataType", EmptyTypeValue);
	
	QuerySelection = Query.Execute().Select();
	
	FormAttributesArray = New Array;
	FormAttributeNames = New Structure;
	FormAttributes = Form.GetAttributes();
		
	While QuerySelection.Next() Do
		//Add attribute to form
						
		ArrayValTypes = New Array;
		ArrayValTypes.Add(TypeOf(QuerySelection.Value));
		
		If TypeOf(QuerySelection.Value) = Type("Number") then
			AttributeValTypeDescription = New TypeDescription(ArrayValTypes, New NumberQualifiers(QuerySelection.Attribute.Digits, QuerySelection.Attribute.FractionDigits, ?(QuerySelection.Attribute.Nonnegative, AllowedSign.Nonnegative, AllowedSign.Any)));
		ElsIf TypeOf(QuerySelection.Value) = Type("Date") then
			AttributeValTypeDescription = New TypeDescription(ArrayValTypes,,, New DateQualifiers(DateFractions.DateTime));
		Else	
			AttributeValTypeDescription = New TypeDescription(ArrayValTypes);
		EndIf;
		FindItem = Form.Items.Find("AA_"+QuerySelection.Attribute.Description);
		If FindItem = Undefined Then
			NewAttribute = New FormAttribute("AA_"+QuerySelection.Attribute.Description, AttributeValTypeDescription, , QuerySelection.Attribute.DescriptionFull, True);
			FormAttributesArray.Add(NewAttribute);
			FormAttributeNames.Insert("AA_"+QuerySelection.Attribute.Description, QuerySelection.Attribute); 
		Else
			For Each FormAttribute In FormAttributes Do
				If FormAttribute.Name = "AA_"+QuerySelection.Attribute.Description Then
					FormAttribute.ValueType = AttributeValTypeDescription;
				EndIf;
			EndDo;
			FindItem.AvailableTypes = AttributeValTypeDescription;
			FindItem.TypeRestriction = AttributeValTypeDescription;
			FindItem.Visible = Not QuerySelection.Hide;
		EndIf;
		
	EndDo; 
	
	If FormAttributesArray.Count()>0 then 
		Form.ChangeAttributes(FormAttributesArray);
		AdditionalParametersList = New Array;
		
		For Each FormAttribute In FormAttributesArray Do
			If FormAttribute.Name = "AdditionalAttributesList" then
				Continue;
			EndIf;
			
			//Add input fields to form
			NewField = Form.Items.Add(FormAttribute.Name, Type("FormField"), AttributesFormGroup);
			NewField.DataPath = FormAttribute.Name;
			If FormAttribute.ValueType.ContainsType(Type("Boolean")) then
				NewField.Type = FormFieldType.CheckBoxField;
			Else
				NewField.Type = FormFieldType.InputField;
				NewField.AvailableTypes = FormAttribute.ValueType;
				
				If NewField.AvailableTypes.ContainsType(Type("CatalogRef.AdditionalAttributeValues")) then
					FilterParameter = New ChoiceParameter("Filter.Owner", FormAttributeNames[FormAttribute.Name]);
					TempArray = New Array();
					TempArray.Add(FilterParameter);
					TempFixedArray = New FixedArray(TempArray);
					NewField.ChoiceParameters = TempFixedArray;
				EndIf;
			EndIf;
									
			Form.AdditionalAttributesList.Add(FormAttribute.Name,Mid(FormAttribute.Name,4));
		EndDo; 
		
		QuerySelection.Reset();
		
	    //Set attribute values on form
		While QuerySelection.Next() Do
			Form["AA_"+QuerySelection.Attribute.Description] = QuerySelection.Value; 
		EndDo; 
	EndIf;
	
EndProcedure

Procedure PutAddtitionalAttributeValuesOnStructure(Form, DestObject) Export
	//Put additional attribute values into AdditionalProperties structure
	AdditionalAttributeValues = New Structure;
	
	For Each Attribute In Form["AdditionalAttributesList"] Do
		AdditionalAttributeValues.Insert(Attribute.Presentation, Form[Attribute.Value]);	
	EndDo;
	
	If AdditionalAttributeValues.Count() then
		DestObject.AdditionalProperties.Insert("AdditionalAttributeValues", AdditionalAttributeValues);
	EndIf;
EndProcedure