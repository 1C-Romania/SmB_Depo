Function CreateValueStructureToPut(Val Source, Val Attributes, ReturnStructure = Undefined) Export
	If ReturnStructure = Undefined Then
		ReturnStructure = New Structure;
	EndIf;
	
	If TypeOf(Attributes) = Type("Structure") Then
		
		For Each CollectionAttributes In Attributes Do
			If TypeOf(Source[CollectionAttributes.Key]) = Type("FormDataCollection") Then
				RowsArray = New Array;
				For Each Row In Source[CollectionAttributes.Key] Do
					RowsArray.Add(CreateValueStructureToPut(Row, CollectionAttributes.Value));
				EndDo;
				ReturnStructure.Insert(CollectionAttributes.Key, RowsArray);
			EndIf;
		EndDo;
	ElsIf TypeOf(Attributes) = Type("Array") Then
		For Each AttributeName In Attributes Do
			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
		EndDo;
	ElsIf TypeOf(Attributes) = Type("String") Then
		While Find(Attributes, ",") > 0 Do
			
			AttributeName = TrimAll(Left(Attributes, Find(Attributes, ",") - 1));
			Attributes = Right(Attributes, StrLen(Attributes) - Find(Attributes, ","));
			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
			
		EndDo;
		If StrLen(Attributes) > 0 Then
			
			AttributeName = TrimAll(Attributes);
			ReturnStructure.Insert(AttributeName, Source[AttributeName]);
			
		EndIf;
	EndIf;
	
	Return ReturnStructure;
EndFunction

// Generates and shows message, which maybe connected to form's item
//
//  Parameters:
//  MessageText - String - Message's text.
//  DataKey                - Any reference on infobase object's or record key
//  Field                       - String - Name of the form's attribute
//  DataPath                - String - Data path to the form's attribute
//  Cancel                      - Bool - Output parameter. Always set to true
//
//	Using examples:
//
//	1. Message output for managed form's item, connected to object's attribute:
//	CommonAtClientAtServer.NotifyUser(
//		Nstr("en = 'Error message.'"), ,
//		"FieldInFormObject",
//		"Object");
//
//	Or:
//	CommonAtClientAtServer.NotifyUser(
//		Nstr("en = 'Error message.'"), ,
//		"Object.FieldInFormObject");
//
//	2. Message output near to managed form's field, connected to form's attribute:
//	CommonAtClientAtServer.NotifyUser(
//		Nstr("en = 'Error message.'"), ,
//		"FormAttributeName");
//
//	3. Output message connected with object
//	CommonAtClientAtServer.NotifyUser(
//		Nstr("en = 'Error message.'"), InfobaseObject, "Author",,Cancel);
//
// 4. Output message for reference
//	CommonAtClientAtServer.NotifyUser(
//		Nstr("en = 'Error message.'"), Ref, , , Cancel);
//
// Cases of incorrect use:
//  1. Simultanious using of DataKey and DataPath
//  2. Storing uncompatible data type into DataKey
//  3. Setting ref without field (or/and datapath)
//
Procedure NotifyUser(
		Val MessageText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False,
		AlertStatus = Undefined,
		TargetID = Undefined) Export
	
	Message = New UserMessage;
	Message.Text = MessageText;
	If Not DataKey = Undefined Then
		StringObject = "";
		Try
			StringObject = String(DataKey);
		Except
		EndTry;
		If Not StringObject = "" And Find(Message.Text, StringObject) = 0 Then
			Message.Text = String(DataKey) + ".
			|" + Message.Text;
		EndIf;
	EndIf;
	Try
		Message.Field = Field;
	Except
	EndTry;
	
	IsThisObject = False;
	
#If NOT (ThinClient OR WebClient) Then
	If DataKey <> Undefined
	   AND XMLTypeOf(DataKey) <> Undefined Then
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsThisObject = Find(ValueTypeAsString, "Object.") > 0;
	EndIf;
#EndIf
	
	If IsThisObject Then
		Message.SetData(DataKey);
	Else
//		Message.DataKey = DataKey;
	EndIf;
	
	If NOT IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
	If Not TargetID = Undefined Then
		Message.TargetID = New UUID(TargetID);
	EndIf;
	
	Message.Message();
	#If Server Then
	If AlertStatus = Enums.AlertType.Warning Then
	#Else
	If AlertStatus = PredefinedValue("Enum.AlertType.Warning") Then
	#EndIf
		Cancel = False;
	Else
		Cancel = True;
	EndIf;
	
EndProcedure

// Function replaces parameters signs in the String to parametrize
// Example: ParametrizeString("Value 1: %P1", New Structure("P1","This is value"))
Function ParametrizeString(StringToParametrize,ParametersStructure) Export
	
	If ParametersStructure = Undefined Then
		Return StringToParametrize;
	EndIf;
	
	LocalStringToParametrize = StringToParametrize;
	
	Array = New Array();
	
	For Each KeyAndValue In ParametersStructure Do
		Array.Insert(0,KeyAndValue.Key);	
	EndDo;
	
	For Each ValueInArray In Array Do
		LocalStringToParametrize = StrReplace(LocalStringToParametrize,String("%"+ValueInArray),String(ParametersStructure[ValueInArray]));
	EndDo;	
	
	Return LocalStringToParametrize;
	
EndFunction

Function IsNotEqualValue(Value1,Value2) Export
	
	If ValueIsFilled(Value1) And ValueIsFilled(Value2) Then
		Return (Value1 <> Value2);
	Else
		Return False;
	EndIf;
	
EndFunction	

/////////////////////////////////////////////////////////////////////////////////////////////////
/// Working with credit card

Function CheckCreditCardNumber(CardNumber) Export
	
	LenghtCardNumber = StrLen(CardNumber);
	Sum = 0;
    Digit = 0;
    AddEnd = 0;
	NumberIsZero = 0;
	
	If (LenghtCardNumber % 2) <> 0 Then
		TimesTwo = False;
	Else
		TimesTwo = True;
	EndIf;
	
	For i = 1 To LenghtCardNumber Do
		
		Digit = Number(Mid(CardNumber, i, 1));
		
		NumberIsZero = NumberIsZero + Digit;
		
		If TimesTwo Then
			AddEnd = Digit * 2;
			If AddEnd > 9 Then
          		AddEnd = AddEnd - 9;
	        EndIf;
      	Else
	        AddEnd = Digit;
		EndIf;
		
      	Sum = Sum + AddEnd;
      	TimesTwo = Not TimesTwo;
		
    EndDo;
	
	If NumberIsZero = 0 Then
		Return True;
	Else
		Modulus = Sum % 10;
		Return Not (Modulus = 0);
	EndIf;
	
EndFunction



////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH TYPES

Function GetStringTypeDescription(StringLenth) Export 
	
	Return CommonAtClientAtServer.GetTypeDescription("String", StringLenth);
	
EndFunction // GetStringTypeDescription()

Function GetNumberTypeDescription(Digits, FractionDigits = 0) Export 
	
	Return CommonAtClientAtServer.GetTypeDescription("Number", Digits, FractionDigits);
	
EndFunction // GetNumberTypeDescription()

Function GetDateTypeDescription(SetDateFractions = Undefined) Export 
	
	Return CommonAtClientAtServer.GetTypeDescription("Date", , , SetDateFractions);
	
EndFunction // GetDateTypeDescription()

Function GetBooleanTypeDescription() Export 
	
	Return CommonAtClientAtServer.GetTypeDescription("Boolean");
	
EndFunction // CommonAtClientAtServer.GetBooleanTypeDescription()

Function GetTypeDescription(TypeName = "", Digits = 0, FractionDigits = 0, SetDateFractions = Undefined) Export 
	
	Var TypeDescription;
	
	If TypeOf(TypeName) = Type("String") Then
		
		Array = New Array;
		
		If Not IsBlankString(TypeName) Then
			Array.Add(Type(TypeName));
		EndIf;
		
		If TypeName = "Number" Then
			
			Qualifier = New NumberQualifiers(Digits, FractionDigits);
			TypeDescription = New TypeDescription(Array, Qualifier);
			
		ElsIf TypeName = "String" Then
			
			If FractionDigits = 0 Then
				Qualifier = New StringQualifiers(Digits);
			Else
				Qualifier = New StringQualifiers(Digits, FractionDigits);
			EndIf;
			
			TypeDescription = New TypeDescription(Array, , Qualifier);
			
		ElsIf TypeName = "Date" Then
			
			If SetDateFractions = Undefined Then
				SetDateFractions = DateFractions.Date;
			EndIf;
			
			Qualifier = New DateQualifiers(SetDateFractions);
			TypeDescription = New TypeDescription(Array, , , Qualifier);
			
		Else
			
			TypeDescription = New TypeDescription(Array);
			
		EndIf;
		
	ElsIf TypeOf(TypeName) = Type("TypeDescription") Then
		
		TypeDescription = TypeName;
		
	EndIf;
	
	Return TypeDescription;
	
EndFunction // GetTypeDescription()

Procedure AdjustValueToTypeRestriction(Value, TypeRestriction, ChooseType = False) Export
	
	If Not TypeRestriction.ContainsType(TypeOf(Value)) Then
		If TypeRestriction.Types().Count() = 0 Then
			If Not ChooseType And Value <> Undefined Then
				Value = Undefined;
			EndIf;
		Else
			AdjustedValue = TypeRestriction.AdjustValue(Value);
			If Value <> AdjustedValue Then
				Value = AdjustedValue;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure SetIncotermsOptions(Object) Export
	
	DeliveryPointStructure = ObjectsExtensionsAtServer.GetAttributesStructureFromRef(Object.DeliveryPoint,New Structure("IncotermsCondition, IncotermsDeliveryPlace"));
	Object.IncotermsCondition = DeliveryPointStructure.IncotermsCondition;
	Object.IncotermsDeliveryPlace = DeliveryPointStructure.IncotermsDeliveryPlace;
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH TABLES

#If ThickClient OR Server Then
Function IsUniqueBarCode(BarCode, ExcludeObjects = Undefined,FoundObjects = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	             |	Items.Ref
	             |FROM
	             |	Catalog.Items AS Items
	             |WHERE
	             |	NOT Items.Ref IN (&ExcludeObjects)
	             |	AND Items.MainBarCode = &BarCode
	             |	AND Items.MainBarCode <> """"
	             |
	             |UNION
	             |
	             |SELECT
	             |	BarCodes.Object
	             |FROM
	             |	InformationRegister.BarCodes AS BarCodes
	             |WHERE
	             |	NOT BarCodes.Object IN (&ExcludeObjects)
	             |	AND BarCodes.BarCode = &BarCode
	             |	AND BarCodes.BarCode <> """"";
	Query.SetParameter("ExcludeObjects",ExcludeObjects);
	Query.SetParameter("BarCode",BarCode);
	FoundObjects = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return (FoundObjects.Count()<1);
	
EndFunction	
#EndIf
