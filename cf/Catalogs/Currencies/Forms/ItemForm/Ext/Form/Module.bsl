
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Parameters.Property("CurrencyCode") Then
			Object.Code = Parameters.CurrencyCode;
		EndIf;
		
		If Parameters.Property("ShortDescription") Then
			Object.Description = Parameters.ShortDescription;
		EndIf;
		
		If Parameters.Property("DescriptionFull") Then
			Object.DescriptionFull = Parameters.DescriptionFull;
		EndIf;
		
		If Parameters.Property("Importing") AND Parameters.Importing Then
			Object.SetRateMethod = Enums.CurrencyRateSetMethods.ExportFromInternet;
		Else 
			Object.SetRateMethod = Enums.CurrencyRateSetMethods.ManualInput;
		EndIf;
		
		If Parameters.Property("WritingParametersInEnglish") Then
			Object.WritingParametersInEnglish = Parameters.WritingParametersInEnglish;
		EndIf;
		
		FillFormByObject();
		
	EndIf;
	
	SetEnabledOfItems(ThisObject);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormByObject();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.WritingParametersInEnglish = WritingParametersInEnglish(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Page "Basic information".

&AtClient
Procedure MainCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Object.Ref);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Page "Currency recipe parameters".

&AtClient
Procedure AmountNumberOnChange(Item)
	
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClient
Procedure InWordsField4InEnglishOnChange(Item)
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField4InEnglishAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField4InEnglishTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8InEnglishOnChange(Item)
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField8InEnglishAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8InEnglishTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField1InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField2InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField3InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField5InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField6InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField7InEnglishOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionLengthOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionLengthAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FractionLengthTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CurrencyRateOnChange(Item)
	SetEnabledOfItems(ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillFormByObject()
	
	ReadWritingParameters();
	
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function WritingParametersInEnglish(Form)
	
	Return Form.InWordsField1HomeLanguage + ", "
			+ Form.InWordsField2HomeLanguage + ", "
			+ Form.InWordsField3HomeLanguage + ", "
			+ Lower(Left(Form.InWordsField4HomeLanguage, 1)) + ", "
			+ Form.InWordsField5HomeLanguage + ", "
			+ Form.InWordsField6HomeLanguage + ", "
			+ Form.InWordsField7HomeLanguage + ", "
			+ Lower(Left(Form.InWordsField8HomeLanguage, 1)) + ", "
			+ Form.FractionalPartLength;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetAmountInWords(Form)
	
	Form.AmountInWords = NumberInWords(Form.AmountNumber, , WritingParametersInEnglish(Form));
	
EndProcedure

&AtServer
Procedure ReadWritingParameters()
	
	// Reads recipe parameters and fills corresponding dialog fields.
	
	ParameterString = StrReplace(Object.WritingParametersInEnglish, ",", Chars.LF);
	
	InWordsField1HomeLanguage = TrimAll(StrGetLine(ParameterString, 1));
	InWordsField2HomeLanguage = TrimAll(StrGetLine(ParameterString, 2));
	InWordsField3HomeLanguage = TrimAll(StrGetLine(ParameterString, 3));
	
	Gender = TrimAll(StrGetLine(ParameterString, 4));
	
	If	  Lower(Gender) = "m" Then
		InWordsField4HomeLanguage = "Male";
	ElsIf Lower(Gender) = "G" Then
		InWordsField4HomeLanguage = "Female";
	ElsIf Lower(Gender) = "From" Then
		InWordsField4HomeLanguage = "Neuter";
	EndIf;
	
	InWordsField5HomeLanguage = TrimAll(StrGetLine(ParameterString, 5));
	InWordsField6HomeLanguage = TrimAll(StrGetLine(ParameterString, 6));
	InWordsField7HomeLanguage = TrimAll(StrGetLine(ParameterString, 7));
	
	Gender = TrimAll(StrGetLine(ParameterString, 8));
	
	If	  Lower(Gender = "m") Then
		InWordsField8HomeLanguage = "Male";
	ElsIf Lower(Gender = "G") Then
		InWordsField8HomeLanguage = "Female";
	ElsIf Lower(Gender = "From") Then
		InWordsField8HomeLanguage = "Neuter";
	EndIf;
	
	FractionalPartLength     = TrimAll(StrGetLine(ParameterString, 9));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetWritingParametersDeclensions(Form)
	
	// Header declension recipe parameters.
	
	Items = Form.Items;
	
	If Form.InWordsField4HomeLanguage = "Female" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField2HomeLanguage.Title = NStr("en='Two';ru='Две'");
	ElsIf Form.InWordsField4HomeLanguage = "Male" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField2HomeLanguage.Title = NStr("en='Two';ru='Две'");
	Else
		Items.InWordsField1HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField2HomeLanguage.Title = NStr("en='Two';ru='Две'");
	EndIf;
	
	If Form.InWordsField8HomeLanguage = "Female" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField6HomeLanguage.Title = NStr("en='Two';ru='Две'");
	ElsIf Form.InWordsField8HomeLanguage = "Male" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField6HomeLanguage.Title = NStr("en='Two';ru='Две'");
	Else
		Items.InWordsField5HomeLanguage.Title = NStr("en='One';ru='Одно'");
		Items.InWordsField6HomeLanguage.Title = NStr("en='Two';ru='Две'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Ref)
	
	// Prepares choice list for subordinated currency
	// so that the subordinated currency didn't get to the list.
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	
	Query.Text = "SELECT Ref, DescriptionFull
	               |FROM
	               |	Catalog.Currencies
	               |WHERE
	               |	Ref <> &Ref
	               |AND
	               |	MainCurrency  = Value(Catalog.Currencies.EmptyRef)
	               |ORDER BY DescriptionFull";
	
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.DescriptionFull);
	EndDo;
	
EndProcedure

&AtClient
Function AutoCompleteByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	For Each ChoiceItem IN Item.ChoiceList Do
		If Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			StandardProcessing = False;
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Function TextEditEndByListChoice(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	StandardProcessing = False;
	
	For Each ChoiceItem IN Item.ChoiceList Do
		If Upper(Text) = Upper(ChoiceItem.Presentation) Then
			StandardProcessing = True;
		ElsIf Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			StandardProcessing = False;
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetEnabledOfItems(Form)
	Items = Form.Items;
	Object = Form.Object;
	Items.GroupMarkupOnRateOtherCurrency.Enabled = Object.SetRateMethod = PredefinedValue("Enum.CurrencyRateSetMethods.MarkupOnExchangeRateOfOtherCurrencies");
	Items.GroupRateCalculationFormula.Enabled = Object.SetRateMethod = PredefinedValue("Enum.CurrencyRateSetMethods.CalculationByFormula");
EndProcedure
#EndRegion















// Rise { Sargsyan N 2016-08-17 
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PresentationsChanged" Then
		RiseFillPresentations(Parameter);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure  RiseFillPresentations(Table)
	Object.MultilingualPresentations.Clear();
	Object.MultilingualPresentations.Load(Table.Unload());
EndProcedure
// Rise } Sargsyan N 2016-08-17
