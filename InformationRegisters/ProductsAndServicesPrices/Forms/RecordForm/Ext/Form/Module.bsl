
&AtServerNoContext
// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
Function GetDataProductsAndServicesOnChange(ProductsAndServices)
	
	Return ProductsAndServices.MeasurementUnit;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

&AtServerNoContext
// It receives data set from the server for procedure PriceKindOnChange.
//
Function GetDataPriceKindOnChange(PriceKind)
	
	DataStructure = New Structure;
	DataStructure.Insert("RoundUp", PriceKind.RoundUp);
	DataStructure.Insert("RoundingOrder", PriceKind.RoundingOrder);
	
	Return DataStructure;
	
EndFunction // GetDataPriceKindOnChange()	

&AtClient
// Rounds a number according to a specified order.
//
// Parameters:
//  Number        - Number to be rounded
//  RoundingOrder - Enums.RoundingMethods - round order 
//  RoundUpward   - Boolean - rounding upward.
//
// Returns:
//  Number        - rounding result.
//
Function RoundPrice(Number, RoundRule, RoundUp) Export
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents. 
	If Not ValueIsFilled(RoundRule) Then
		RoundingOrder = RoundingMethodsRound0_01; 
	Else
		RoundingOrder = RoundRule;
	EndIf;
	Order = Number(String(RoundingOrder));
	
	// calculate quantity of intervals included in number
	QuantityInterval	= Number / Order;
	
	// calculate an integer quantity of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are divided integrally. No need to round.
		Result	= Number;
	Else
		If RoundUp Then
			
			// During 0.05 rounding 0.371 must be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
		Else
			
			// During 0.05 rounding 0.371 must be rounded to
			// 0.35 and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, 0, RoundMode.Round15as20);
		EndIf; 
	EndIf;
	
	Return Result;
	
EndFunction // RoundPrice()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If Not ValueIsFilled(Record.SourceRecordKey.PriceKind) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure")
			AND Parameters.FillingValues.Property("ProductsAndServices")
			AND ValueIsFilled(Parameters.FillingValues.ProductsAndServices) Then
			
			Record.MeasurementUnit = Parameters.FillingValues.ProductsAndServices.MeasurementUnit;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Record.PriceKind) Then
		
		Record.PriceKind = Catalogs.PriceKinds.GetMainKindOfSalePrices();
		
	EndIf;
	
	RoundUp = Record.PriceKind.RoundUp;
	RoundingOrder = Record.PriceKind.RoundingOrder;
	RoundingMethodsRound0_01 = Enums.RoundingMethods.Round0_01;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	ThisForm.ReadOnly = Not AllowedEditDocumentPrices;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, StandardProcessing)
	If RecordWasRecorded Then
		Notify("PriceChanged", RecordWasRecorded);
	EndIf;
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.PriceKind.CalculatesDynamically Then
		
		Message 		= New UserMessage;
		Message.Text = "You can not write data with dynamic price kinds!";
		Message.Field 	= "Record.PriceKind";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Modified Then
		CurrentObject.Author = Users.CurrentUser();
	EndIf; 
	
EndProcedure

&AtClient
// BeforeRecord event handler procedure.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("RegisterProductsAndServicesEntryPricesInformationInteractively");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure //BeforeWrite()

&AtClient
// Procedure - event handler AfterWrite form.
//
Procedure AfterWrite(WriteParameters)
	RecordWasRecorded = True;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HANDLERS OF THE FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of the ProductsAndServices input field.
//
Procedure ProductsAndServicesOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsAndServicesOnChange(Record.ProductsAndServices);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure PricesKindOnChange(Item)
	
	DataStructure = GetDataPriceKindOnChange(Record.PriceKind);
	RoundUp = DataStructure.RoundUp;
	RoundingOrder = DataStructure.RoundingOrder;
	
	Record.Price = RoundPrice(Record.Price, RoundingOrder, RoundUp);
	
EndProcedure // PriceKindOnChange()

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure PriceOnChange(Item)
	
	Record.Price = RoundPrice(Record.Price, RoundingOrder, RoundUp);
	
EndProcedure // PriceOnChange()






