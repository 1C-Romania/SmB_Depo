
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	SelectTypeValue = AttributeTypeDescription.AdjustValue();
	
	If SelectTypeValue<>Undefined then
		Object.AttributeValueType = SelectTypeValue;
		Object.AttributeValueTypeAsString = String(TypeOf(Object.AttributeValueType));
	else
		Cancel = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Please choose attribute value type';pl='Wybierz typ atrybutu';ru='Выберите тип атрибута'");
		Message.Field = "Items.AttributeTypeDescription";
		Message.Message();
	Endif;	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	AdditionalAttributeMetadata = Metadata.Catalogs.AdditionalAttributes;
	Items.AttributeTypeDescription.AvailableTypes = AdditionalAttributeMetadata.Attributes.AttributeValueType.Type;
	
	If Object.AttributeValueType <> Undefined then
		ArrayTypes = New Array;
		ArrayTypes.Add(TypeOf(Object.AttributeValueType));
		If TypeOf(Object.AttributeValueType) = Type("Number") Then
			AttributeTypeDescription = New TypeDescription("Number",,, New NumberQualifiers(Object.Digits, Object.FractionDigits, ?(Object.Nonnegative, AllowedSign.Nonnegative, AllowedSign.Any)));
		ElsIf TypeOf(Object.AttributeValueType) = Type("Date") Then
			AttributeTypeDescription = New TypeDescription("Date",,,,, New DateQualifiers(?(Object.UseDate And Object.UseTime, DateFractions.DateTime,?(Object.UseDate, DateFractions.Date, DateFractions.Time))));
		Else
			AttributeTypeDescription = New TypeDescription(ArrayTypes);
		EndIf;
		
	Else
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("CatalogRef.AdditionalAttributeValues"));
		AttributeTypeDescription = New TypeDescription(ArrayTypes);
	EndIf;
	
	If ValueIsFilled(Object.Ref) then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	COUNT(AdditionalAttributeValues.Attribute) AS AttributeCount
		|FROM
		|	InformationRegister.AdditionalAttributeValues AS AdditionalAttributeValues
		|WHERE
		|	AdditionalAttributeValues.Attribute = &Attribute";
		
		Query.SetParameter("Attribute", Object.Ref);
		QueryResult = Query.Execute().Select();
		QueryResult.Next();
		
		If QueryResult.AttributeCount > 0 Then
			Items.AttributeTypeDescription.Enabled = False;
		EndIf;
	EndIf;	
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	If Not ValueIsFilled(Object.DescriptionFull) then
		Object.DescriptionFull = Object.Description;
	Endif;	
EndProcedure

&AtClient
Procedure UpdateDialog()
	Items.GroupDateTime.Visible = (AttributeTypeDescription = New TypeDescription("Date"));
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateDialog();
EndProcedure

&AtClient
Procedure AttributeTypeDescriptionOnChange(Item)
	IsDate = False;
	IsNumber = False;
	For Each Type In AttributeTypeDescription.Types() Do
		If Type = Type("Date") Then
			IsDate = True;
		ElsIf Type = Type("Number") Then
			IsNumber = True;
		EndIf;
	EndDo;
	If IsDate Then
		If AttributeTypeDescription.DateQualifiers.DateFractions = DateFractions.Date Then
			Object.UseDate = True;
			Object.UseTime = False;
		ElsIf AttributeTypeDescription.DateQualifiers.DateFractions = DateFractions.Time Then
			Object.UseDate = False;
			Object.UseTime = True;
		ElsIf AttributeTypeDescription.DateQualifiers.DateFractions = DateFractions.DateTime Then
			Object.UseDate = True;
			Object.UseTime = True;
		EndIf;
	EndIf;
	If IsNumber Then
		Object.Digits = AttributeTypeDescription.NumberQualifiers.Digits;
		Object.FractionDigits = AttributeTypeDescription.NumberQualifiers.FractionDigits;
		Object.Nonnegative = (AttributeTypeDescription.NumberQualifiers.AllowedSign = AllowedSign.Nonnegative);
	EndIf;
	UpdateDialog();
EndProcedure
