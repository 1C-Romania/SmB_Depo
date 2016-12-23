////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Function returns a tabular document for printing the waybil
Function PrintForm(ObjectsArray, PrintParameters, PrintObjects) Export

	SpreadsheetDocument			= New SpreadsheetDocument;
	Template 						= FormAttributeToValue("Object").GetTemplate("PF_MXL_WayBill");
	PutHorizBreak	= False;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If PutHorizBreak Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		Else
			PutHorizBreak	= True;
		EndIf;
		
		FirstLineNumber 						= SpreadsheetDocument.TableHeight + 1;
		SpreadsheetDocument.PrintParametersName 	= "PRINT_PARAMETERS_PrintWayBill_WB";
		
		//:::Front
		TemplateArea 				= Template.GetArea("FirstPart");
		TemplateArea.Parameters.Fill(PrintParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		SpreadsheetDocument.PutHorizontalPageBreak();
		
		TemplateArea 				= Template.GetArea("SecondPart");
		TemplateArea.Parameters.Fill(PrintParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		SpreadsheetDocument.PutHorizontalPageBreak();
		
		//:::Reverse
		TemplateAreaBackSide		= Template.GetArea("ThirdPart");
		TemplateAreaBackSide.Parameters.Fill(PrintParameters);
		SpreadsheetDocument.Put(TemplateAreaBackSide);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, SpreadsheetDocument.TableHeight + 1, PrintObjects, CurrentDocument);
		
		//:::Layout parameters
		SpreadsheetDocument.TopMargin = 0;
		SpreadsheetDocument.LeftMargin  = 0;
		SpreadsheetDocument.BottomMargin  = 0;
		SpreadsheetDocument.RightMargin = 0;
		SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

&AtServer
// Procedure fills form attributes with values from the basis document
// 
// Not all attributes are filled
//
Procedure FillByDocumentCustomerInvoice()
	
	BasisDocument	= Object.Document;
	DocumentMetadata	= BasisDocument.Metadata();
	InstanceNumber 	= 1;
	
	//:::Consignor
	ShipperKind			= "Leg. person";
	If Not DocumentMetadata.Attributes.Find("Consignor") = Undefined 
		AND ValueIsFilled(BasisDocument.Consignor) Then
		
		ShipperForPrinting	= BasisDocument.Consignor;
		
	ElsIf ValueIsFilled(BasisDocument.StructuralUnit) 
		AND ValueIsFilled(BasisDocument.StructuralUnit.Company)  Then
		
		ShipperForPrinting	= BasisDocument.StructuralUnit.Company;
		
	Else
		
		ShipperForPrinting	= BasisDocument.Company;
		
	EndIf;
	
	If ValueIsFilled(ShipperForPrinting) Then
	
		ThisIsInd					= (ShipperForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ShipperKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutShipper 	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ShipperForPrinting, BasisDocument.Date);
		Consignor 			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutShipper,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
														
														
		If TypeOf(ShipperForPrinting) = Type("CatalogRef.Companies")
			AND ValueIsFilled(BasisDocument.StructuralUnit.FRP) Then
			
			ResponsibleShipper = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(BasisDocument.Date, BasisDocument.StructuralUnit.FRP);
			
		ElsIf TypeOf(ShipperForPrinting) = Type("CatalogRef.Counterparties") 
			AND Not ShipperForPrinting.Metadata().Attributes.Find("ContactPerson") = UNDEFINED Then
			
			ResponsibleShipper = ShipperForPrinting.ContactPerson.Description;
			
		EndIf;
		
	EndIf;
	
	//:::Consignee
	ConsigneeKind			= "Leg. person";
	If Not DocumentMetadata.Attributes.Find("Consignee") = Undefined 
		AND ValueIsFilled(BasisDocument.Consignee) Then
		
		ConsigneeForPrinting	= BasisDocument.Consignee;
		
	Else
		
		ConsigneeForPrinting	= BasisDocument.Counterparty;
		
	EndIf;
	
	If ValueIsFilled(ConsigneeForPrinting) Then
		
		ThisIsInd					= (ConsigneeForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ConsigneeKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutConsignee	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ConsigneeForPrinting, BasisDocument.Date);
		Consignee				= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
														
		If Not ConsigneeForPrinting.Metadata().Attributes.Find("ContactPerson") = UNDEFINED Then
			
			ResponsibleConsignee = ConsigneeForPrinting.ContactPerson.Description;
			
		EndIf;
		
	EndIf;
	
	//:::Carrier
	CarrierKind	= "Leg. person";
	
EndProcedure //FillByDocument()

&AtServer
// Procedure fills form attributes with values from the basis document
// 
// Not all attributes are filled
//
Procedure FillByDocumentInventoryTransfer()
	
	BasisDocument	= Object.Document;
	DocumentMetadata	= BasisDocument.Metadata();
	InstanceNumber 	= 1;
	
	//:::Consignor
	ShipperKind			= "Leg. person";
	If ValueIsFilled(BasisDocument.StructuralUnit) 
		AND ValueIsFilled(BasisDocument.StructuralUnit.Company) Then
		
		ShipperForPrinting	= BasisDocument.StructuralUnit.Company;
		ThisIsInd					= (ShipperForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ShipperKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutShipper 	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ShipperForPrinting, BasisDocument.Date);
		Consignor 			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutShipper,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
		
		ResponsibleShipper = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(BasisDocument.Date, BasisDocument.StructuralUnit.FRP);
		
	EndIf;
	
	//:::Consignee
	ConsigneeKind			= "Leg. person";
	If ValueIsFilled(BasisDocument.StructuralUnitPayee) 
		AND ValueIsFilled(BasisDocument.StructuralUnitPayee.Company) Then
		
		ConsigneeForPrinting	= BasisDocument.StructuralUnitPayee.Company; 
		ThisIsInd					= (ConsigneeForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ConsigneeKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutConsignee	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ConsigneeForPrinting, BasisDocument.Date);
		Consignee				= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
		
		ResponsibleConsignee = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(BasisDocument.Date, BasisDocument.StructuralUnitPayee.FRP);
		
	EndIf;
	
	//:::Carrier
	CarrierKind	= "Leg. person";
	
EndProcedure //FillByDocumentInventoryTransfer()

&AtServer
// Procedure fills form attributes with values from the basis document
// 
// Not all attributes are filled
//
Procedure FillByDocumentProcessingReport()
	
	BasisDocument	= Object.Document;
	DocumentMetadata	= BasisDocument.Metadata();
	InstanceNumber 	= 1;
	
	//:::Consignor
	ShipperKind			= "Leg. person";
	If Not DocumentMetadata.Attributes.Find("Consignor") = Undefined 
		AND ValueIsFilled(BasisDocument.Consignor) Then
		
		ShipperForPrinting	= BasisDocument.Consignor;
		
	ElsIf ValueIsFilled(BasisDocument.StructuralUnit) 
		AND ValueIsFilled(BasisDocument.StructuralUnit.Company)  Then
		
		ShipperForPrinting	= BasisDocument.StructuralUnit.Company;
		
	Else
		
		ShipperForPrinting	= BasisDocument.Company;
		
	EndIf;
	
	If ValueIsFilled(ShipperForPrinting) Then
	
		ThisIsInd					= (ShipperForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ShipperKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutShipper 	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ShipperForPrinting, BasisDocument.Date);
		Consignor 			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutShipper,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
														
														
		If ValueIsFilled(BasisDocument.StructuralUnit.FRP) Then
			
			ResponsibleShipper = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(BasisDocument.Date, BasisDocument.StructuralUnit.FRP);
			
		EndIf;
		
	EndIf;
	
	//:::Consignee
	ConsigneeKind			= "Leg. person";
	If Not DocumentMetadata.Attributes.Find("Consignee") = Undefined 
		AND ValueIsFilled(BasisDocument.Consignee) Then
		
		ConsigneeForPrinting	= BasisDocument.Consignee;
		
	Else
		
		ConsigneeForPrinting	= BasisDocument.Counterparty;
		
	EndIf;
	
	If ValueIsFilled(ConsigneeForPrinting) Then
		
		ThisIsInd					= (ConsigneeForPrinting.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind);
		ConsigneeKind			= ?(ThisIsInd, "Individual", "Leg. person");
		InfoAboutConsignee	= SmallBusinessServer.InfoAboutLegalEntityIndividual(ConsigneeForPrinting, BasisDocument.Date);
		Consignee				= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutConsignee,
										?(ThisIsInd, "FullDescr, TIN, ActualAddress", 
														"FullDescr, ActualAddress, PhoneNumbers"));
														
		If Not ConsigneeForPrinting.Metadata().Attributes.Find("ContactPerson") = UNDEFINED Then
			
			ResponsibleConsignee = ConsigneeForPrinting.ContactPerson.Description;
			
		EndIf;
		
	EndIf;
	
	//:::Carrier
	CarrierKind	= "Leg. person";
	
EndProcedure //FillByDocumentInventoryTransfer()

&AtClient
// Collects information row on the acceptance of the order by data of the several form attributes
// 
Procedure UpdateInformationAboutOrderAcceptance()
	
	InformationAboutOrderAcceptance = "";
	
	If ValueIsFilled(OrderAcceptanceDate) Then
		
		InformationAboutOrderAcceptance = NStr("en='Order by ';ru='Заказ от '") + Format(OrderAcceptanceDate, "DLF=DD");
		
	EndIf;
	
	If ValueIsFilled(OrderAccepted) Then
		
		InformationAboutOrderAcceptance = InformationAboutOrderAcceptance + NStr("en='; order accepted by ';ru='; заказ принял(а) '") + OrderAccepted;
		
	EndIf;
	
	If ValueIsFilled(PositionOfEmployeeAcceptedOrder) Then
		
		InformationAboutOrderAcceptance = InformationAboutOrderAcceptance + " (" + PositionOfEmployeeAcceptedOrder + ")";
		
	EndIf;
	
EndProcedure

&AtServer
//  Procedure restores the settings from the common settings storage
//
//
Procedure RestoreSettings(custom = True)
	
	SetPrivilegedMode(True);
	
	If custom Then
		
		FormFieldsStructure = CommonSettingsStorage.Load("DataProcessors.PrintWayBill",	"custom",			"Print settings");
		
	Else
		
		FormFieldsStructure = CommonSettingsStorage.Load("DataProcessors.PrintWayBill",	TrimAll(Object.Document),	"Print settings",		"Common");
		
	EndIf;
	
	If Not FormFieldsStructure = Undefined Then
		
		FillPropertyValues(ThisForm, FormFieldsStructure);
		
	EndIf;
	
	//  Refill the fields with values from the document
	If Not ValueIsFilled(Object.Document) Then
		
		Return;
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.CustomerInvoice") Then
		
		FillByDocumentCustomerInvoice();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.InventoryTransfer") Then
		
		FillByDocumentInventoryTransfer();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.ProcessingReport") Then
		
		FillByDocumentProcessingReport();
		
	EndIf;
	
EndProcedure // RestoreSettings()

&AtServer
//  Procedure saves the settings in the common settings storage
//
//
Procedure SaveSettings(custom = True)
	
	SetPrivilegedMode(True);
	
	FormFieldsStructure = GenerateFormFieldStructureAtServer();
	
	If custom Then
		
		CommonSettingsStorage.Save("DataProcessors.PrintWayBill",	"custom", 		FormFieldsStructure,	"Print settings");
		
	Else
		
		CommonSettingsStorage.Save("DataProcessors.PrintWayBill",	TrimAll(Object.Document),	FormFieldsStructure,	"Print settings",	"Common");
		
	EndIf;
	
EndProcedure //SaveUserPattern()

&AtServer
//  Creates a structure that is filled with the form fields values
//
//  Structure key	- field ID;
//  Value 		- field value;
//  
Function GenerateFormFieldStructureAtServer()
	
	FormFieldsStructure = New Structure();
	
	//::: Header
	FormFieldsStructure.Insert("InstanceNumber", 				InstanceNumber);
	FormFieldsStructure.Insert("RequestDate", 						RequestDate);
	FormFieldsStructure.Insert("RequestNumber", 					RequestNumber);
	
	//::: Section 1
	FormFieldsStructure.Insert("Consignor", 				Consignor);
	FormFieldsStructure.Insert("ShipperContinuation",		ShipperContinuation);
	//FormFieldsStructure.Insert("ResponsibleShipper",	ResponsibleShipper);
	
	//::: Section 2
	FormFieldsStructure.Insert("Consignee", 				Consignee);
	FormFieldsStructure.Insert("ConsigneeContinuation",		ConsigneeContinuation);
	//FormFieldsStructure.Insert("ResponsibleConsignee",	ResponsibleConsignee);
	
	//::: Section 3
	FormFieldsStructure.Insert("CargoDescription", 				CargoDescription);
	FormFieldsStructure.Insert("NumberOfPackagesMarking",		NumberOfPackagesMarking);
	FormFieldsStructure.Insert("CargoItems", 					CargoItems);
	FormFieldsStructure.Insert("InfoAboutHazardousMaterials",	InfoAboutHazardousMaterials);
	
	//::: Section 4
	FormFieldsStructure.Insert("DocumentsAttached", 			DocumentsAttached);
	FormFieldsStructure.Insert("CertificatesAttached", 			CertificatesAttached);
	
	//::: Section 5
	FormFieldsStructure.Insert("CargoTransportParameters",	CargoTransportParameters);
	FormFieldsStructure.Insert("NecessaryInstructions", 			NecessaryInstructions);
	FormFieldsStructure.Insert("Recommendations", 					Recommendations);
	
	//::: Section 6
	FormFieldsStructure.Insert("ImportingAddress", 					ImportingAddress);
	FormFieldsStructure.Insert("SpottingTermForImporting", 			SpottingTermForImporting);
	FormFieldsStructure.Insert("ActualArrivedSection6",		ActualArrivedSection6);
	FormFieldsStructure.Insert("ActualDispatchedSection6",		ActualDispatchedSection6);
	FormFieldsStructure.Insert("StateOfCargoOnImporting",		StateOfCargoOnImporting);
	FormFieldsStructure.Insert("CargoWeightOnImporting",			CargoWeightOnImporting);
	FormFieldsStructure.Insert("NumberOfPackagesOnImporting", 		NumberOfPackagesOnImporting);
	FormFieldsStructure.Insert("ShipperSignatureSection6",ShipperSignatureSection6);
	FormFieldsStructure.Insert("DriverSignatureSection6", 		DriverSignatureSection6);
	
	//::: Section 7
	FormFieldsStructure.Insert("ExportingAddress", 					ExportingAddress);
	FormFieldsStructure.Insert("SpottingTermForExporting", 			SpottingTermForExporting);
	FormFieldsStructure.Insert("ActualArrivedSection7", 		ActualArrivedSection7);
	FormFieldsStructure.Insert("ActualDispatchedSection7", 		ActualDispatchedSection7);
	FormFieldsStructure.Insert("StateOfCargoOnImporting",		StateOfCargoOnExporting);
	FormFieldsStructure.Insert("CargoWeightOnExporting",			CargoWeightOnExporting);
	FormFieldsStructure.Insert("NumberOfPackagesOnExporting", 		NumberOfPackagesOnExporting);
	FormFieldsStructure.Insert("ShipperSignatureSection7",ShipperSignatureSection7);
	FormFieldsStructure.Insert("DriverSignatureSection7", 		DriverSignatureSection7);
	
	//::: Section 8
	FormFieldsStructure.Insert("CargoLostTerm", 				CargoLostTerm);
	FormFieldsStructure.Insert("PaymentAmountAndLimStoragePeriod",	PaymentAmountAndLimStoragePeriod);
	FormFieldsStructure.Insert("CargoWeightEstimationMethod",		CargoWeightEstimationMethod);
	FormFieldsStructure.Insert("FineDueToFaultOfCarrier", 			FineDueToFaultOfCarrier);
	FormFieldsStructure.Insert("FineForDowntime", 					FineForDowntime);
	
	//::: Section 9
	FormFieldsStructure.Insert("OrderAcceptanceDate", 				OrderAcceptanceDate);
	FormFieldsStructure.Insert("OrderAccepted", 					OrderAccepted);
	FormFieldsStructure.Insert("PositionOfEmployeeAcceptedOrder",		PositionOfEmployeeAcceptedOrder);
	
	//::: Section 10
	FormFieldsStructure.Insert("Carrier", 						Carrier);
	FormFieldsStructure.Insert("CarrierContinuation",			CarrierContinuation);
	FormFieldsStructure.Insert("ResponsibleForShipping",		ResponsibleForShipping);
	
	//::: Section 11
	FormFieldsStructure.Insert("TypeModel", 						TypeModel);
	FormFieldsStructure.Insert("RegistrationNumbers",			RegistrationNumbers);
	
	//::: Section 12
	FormFieldsStructure.Insert("ActualCargoState",		ActualCargoState);
	FormFieldsStructure.Insert("ChangingCarriageConditions",		ChangingCarriageConditions);
	FormFieldsStructure.Insert("ActualPackageState",		ActualPackageState);
	FormFieldsStructure.Insert("ChangingConditionsOnExporting",		ChangingConditionsOnExporting);
	
	//::: Section 13
	FormFieldsStructure.Insert("OtherConditions", 					OtherConditions);
	FormFieldsStructure.Insert("DriverWorkRestSchedule",		DriverWorkRestSchedule);
	
	//::: Section 14
	FormFieldsStructure.Insert("ReconsignmentDateForm",			ReconsignmentDateForm);
	FormFieldsStructure.Insert("WhoWasMadeRerouting", 					WhoWasMadeRerouting);
	FormFieldsStructure.Insert("NewDischargePoint", 				NewDischargePoint);
	FormFieldsStructure.Insert("NewConsignee", 			NewConsignee);
	
	//::: Section 15
	FormFieldsStructure.Insert("ServiceChargeInNationalCurrency", ServiceChargeInNationalCurrency);
	FormFieldsStructure.Insert("CalculationsOrder", 					CalculationsOrder);
	FormFieldsStructure.Insert("CarriageChargeAmount", 			CarriageChargeAmount);
	FormFieldsStructure.Insert("ExpensesForShowingToShipper", ExpensesForShowingToShipper);
	FormFieldsStructure.Insert("CustomDutiesAndFeesPayment",	CustomDutiesAndFeesPayment);
	FormFieldsStructure.Insert("CargoHandlingOperations", CargoHandlingOperations);
	FormFieldsStructure.Insert("ConsignorPoint15_6", 		ConsignorPoint15_6);
	
	//::: Section 16 (not available)
	FormFieldsStructure.Insert("ShipperShortlyPoint16_1",	ShipperShortlyPoint16_1);
	FormFieldsStructure.Insert("DateOfCompilationShipper",	DateOfCompilationShipper);
	FormFieldsStructure.Insert("CarrierShortlyPoint16_3", 		CarrierShortlyPoint16_3);
	FormFieldsStructure.Insert("DateOfCompilationCarrier", 		DateOfCompilationCarrier);
	
	//::: Section 17 (not available)
	
	Return FormFieldsStructure;
	
EndFunction  // GenerateFormFieldStructureAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM AND COMMANDS EVENT HANDLERS

&AtClient
// Procedure opens a form for printing BoL
//
Procedure PrintWayBill(Command)
	
	IsNotPopulatedFromForm = "";
	
	PrintParameters = New Structure();
	
	//::: Header
	PrintParameters.Insert("Point0_1", InstanceNumber);
	PrintParameters.Insert("Point0_2", RequestDate);
	PrintParameters.Insert("Point0_3", RequestNumber);
	
	//::: Section 1
	PrintParameters.Insert("Point1_1", Consignor);
	PrintParameters.Insert("Point1_2", ShipperContinuation);
	//PrintParameters.Insert("SKU1_3", ResponsibleShipper);
	
	//::: Section 2
	PrintParameters.Insert("Item2_1", Consignee);
	PrintParameters.Insert("Point2_2", ConsigneeContinuation);
	//PrintParameters.Insert("Item2_3", ResponsibleConsignee);
	
	//::: Section 3
	PrintParameters.Insert("Point3_1", CargoDescription);
	PrintParameters.Insert("Point3_2", NumberOfPackagesMarking);
	PrintParameters.Insert("Point3_3", CargoItems);
	PrintParameters.Insert("Point3_4", InfoAboutHazardousMaterials);
	
	//::: Section 4
	PrintParameters.Insert("Point4_1", DocumentsAttached);
	PrintParameters.Insert("Point4_2", CertificatesAttached);
	
	//::: Section 5
	PrintParameters.Insert("Point5_1", CargoTransportParameters);
	PrintParameters.Insert("Point5_2", NecessaryInstructions);
	PrintParameters.Insert("Point5_3", Recommendations);
	
	//::: Section 6
	PrintParameters.Insert("Point6_1", ImportingAddress);
	PrintParameters.Insert("Point6_2", SpottingTermForImporting);
	PrintParameters.Insert("Point6_3", ActualArrivedSection6);
	PrintParameters.Insert("Point6_4", ActualDispatchedSection6);
	PrintParameters.Insert("Point6_5", StateOfCargoOnImporting);
	PrintParameters.Insert("Point6_6", CargoWeightOnImporting);
	PrintParameters.Insert("Point6_7", NumberOfPackagesOnImporting);
	PrintParameters.Insert("Point6_8", ShipperSignatureSection6);
	PrintParameters.Insert("Point6_9", DriverSignatureSection6);
	
	//::: Section 7
	PrintParameters.Insert("Point7_1", ExportingAddress);
	PrintParameters.Insert("Point7_2", SpottingTermForExporting);
	PrintParameters.Insert("Point7_3", ActualArrivedSection7);
	PrintParameters.Insert("Point7_4", ActualDispatchedSection7);
	PrintParameters.Insert("Point7_5", StateOfCargoOnExporting);
	PrintParameters.Insert("Item7_6", CargoWeightOnExporting);
	PrintParameters.Insert("Point7_7", NumberOfPackagesOnExporting);
	PrintParameters.Insert("Point7_8", ShipperSignatureSection7);
	PrintParameters.Insert("Point7_9", DriverSignatureSection7);
	
	//::: Section 8
	PrintParameters.Insert("Point8_1", CargoLostTerm);
	PrintParameters.Insert("Point8_2", PaymentAmountAndLimStoragePeriod);
	PrintParameters.Insert("Point8_3", CargoWeightEstimationMethod);
	PrintParameters.Insert("Point8_4", FineDueToFaultOfCarrier);
	PrintParameters.Insert("Point8_5", FineForDowntime);
	
	//::: Section 9
	PrintParameters.Insert("Point9_1", OrderAcceptanceDate);
	
	TextPoint9_2 = ?(IsBlankString(PositionOfEmployeeAcceptedOrder),
						OrderAccepted,
						OrderAccepted + " (" + PositionOfEmployeeAcceptedOrder + ")");
	PrintParameters.Insert("Point9_2", TextPoint9_2);
	
	//::: Section 10
	//PrintParameters.Insert("Point10_1", CarrierKind);
	PrintParameters.Insert("Point10_1", Carrier);
	PrintParameters.Insert("Point10_2", CarrierContinuation);
	PrintParameters.Insert("Point10_3", ResponsibleForShipping);
	
	//::: Section 11
	PrintParameters.Insert("Point11_1", TypeModel);
	PrintParameters.Insert("Point11_2", RegistrationNumbers);
	
	//::: Section 12
	PrintParameters.Insert("Point12_1", ActualCargoState);
	PrintParameters.Insert("Point12_2", ChangingCarriageConditions);
	PrintParameters.Insert("Point12_3", ActualPackageState);
	PrintParameters.Insert("Point12_4", ChangingConditionsOnExporting);
	
	//::: Section 13
	PrintParameters.Insert("Point13_1", OtherConditions);
	PrintParameters.Insert("Point13_2", DriverWorkRestSchedule);
	
	//::: Section 14
	PrintParameters.Insert("Point14_1", ReconsignmentDateForm);
	PrintParameters.Insert("Point14_2", WhoWasMadeRerouting);
	PrintParameters.Insert("Point14_3", NewDischargePoint);
	PrintParameters.Insert("Point14_4", NewConsignee);
	
	//::: Section 15
	PrintParameters.Insert("Point15_1", "" + ServiceChargeInNationalCurrency + " dollar; " + CalculationsOrder);
	PrintParameters.Insert("Point15_2", CarriageChargeAmount);
	PrintParameters.Insert("Point15_3", ExpensesForShowingToShipper);
	PrintParameters.Insert("Point15_4", CustomDutiesAndFeesPayment);
	PrintParameters.Insert("Point15_5", CargoHandlingOperations);
	PrintParameters.Insert("Point15_6", ConsignorPoint15_6);
	
	//::: Section 16
	PrintParameters.Insert("Point16_1", ShipperShortlyPoint16_1);
	PrintParameters.Insert("Point16_2", DateOfCompilationShipper);
	PrintParameters.Insert("Point16_3", CarrierShortlyPoint16_3);
	PrintParameters.Insert("Point16_4", DateOfCompilationCarrier);
	
	//::: Section 17 (paragraph contains no parameters)
	
	CommandParameter 			= New Array;
	CommandParameter.Add(Object.Document);
	CommandExecuteParameters 	= New Structure;
	PrintManagementClient.ExecutePrintCommand("DataProcessor.PrintWayBill", "CN", CommandParameter, CommandExecuteParameters, PrintParameters);
	
	//::: Remember the form attributes values for the document
	SaveSettings(False);
	
EndProcedure //PrintWayBillExecute()

&AtServer
// Procedure-handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Document") Then
		
		Object.Document = Parameters.Document;
		
	EndIf;
	
	If Not ValueIsFilled(Object.Document) Then
		
		Return;
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.CustomerInvoice") Then
		
		FillByDocumentCustomerInvoice();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.InventoryTransfer") Then
		
		FillByDocumentInventoryTransfer();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.ProcessingReport") Then
		
		FillByDocumentProcessingReport();
		
	EndIf;
	
	RestoreSettings(False);
	
EndProcedure //OnCreateAtServer()

&AtClient
// Procedure - handler of the Fill command
// 
Procedure Fill()
	
	If Not ValueIsFilled(Object.Document) Then
		
		Return;
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.CustomerInvoice") Then
		
		FillByDocumentCustomerInvoice();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.InventoryTransfer") Then
		
		FillByDocumentInventoryTransfer();
		
	ElsIf TypeOf(Object.Document) = Type("DocumentRef.ProcessingReport") Then
		
		FillByDocumentProcessingReport();
		
	EndIf;
	
EndProcedure //Fill()

&AtClient
// Procedure - event handler OnChange of the OrderAcceptanceDate field
//
Procedure OrderAcceptanceDateOnChange(Item)
	
	UpdateInformationAboutOrderAcceptance();
	
EndProcedure //OrderAcceptanceDateOnChange()

&AtClient
// Procedure - event handler OnChange of the OrderAccepted field
//
Procedure OrderAcceptedOnChange(Item)
	
	UpdateInformationAboutOrderAcceptance();
	
EndProcedure //OrderAcceptedOnChange()

&AtClient
// Procedure - event handler OnChange of the PositionOfEmployeeAcceptedOrder field
Procedure PositionOfEmployeeAcceptedOrderOnChange(Item)
	
	UpdateInformationAboutOrderAcceptance();
	
EndProcedure //PositionOfEmployeeAcceptedOrderOnChange()

&AtClient
// Procedure - event handler OnChange of the Document attribute
//
Procedure DocumentOnChange(Item)
	
	Fill()
	
EndProcedure //DocumentOnChange()

&AtClient
//  Procedure initializes the form values
//  fields saving in the common settings storage.
//
Procedure SaveFieldsValue(Command)
	
	SaveSettings();
	
EndProcedure //SaveFieldsValue()

&AtClient
//  Procedure initializes recovery of user
//  setting and filling of the form fields from the restored setting
//
Procedure RestoreFieldsValue(Command)
	
	RestoreSettings();
	
EndProcedure //RestoreFieldsValue()
//














