#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Receives object attributes which it is required to lock from change
//
// Parameters:
//  No
//
// Returns:
//  Array - lockable object attributes
//
Function GetObjectAttributesBeingLocked() Export

	Result = New Array;
	Result.Add("PeripheralsType");
	
	Return Result;

EndFunction

#EndRegion

#Region PrintInterface

// Function forms print form Product codes
//
Function GeneratePrintFormProductsCodes(ObjectsArray, PrintObjects, PrintParameters)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProductCodes";
	
	Template = PrintManagement.PrintedFormsTemplate("Catalog.ExchangeWithPeripheralsOfflineRules.PF_MXL_ProductCodes");
	FirstDocument = True;
	
	For Each Object IN ObjectsArray Do
		
		PeripheralsOfflineServerCall.RefreshProductProduct(Object);
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("en='Product codes';ru='Коды товаров'");
		TemplateArea.Parameters.ExchangeRule  = Object;
		SpreadsheetDocument.Put(TemplateArea);
		
		AreaCode   = Template.GetArea("TableHeader|Code");
		AreaProduct = Template.GetArea("TableHeader|Product");
		SpreadsheetDocument.Put(AreaCode);
		SpreadsheetDocument.Join(AreaProduct);
		
		AreaCode   = Template.GetArea("String|Code");
		AreaProduct = Template.GetArea("String|Product");
		
		Products = PeripheralsOfflineServerCall.GetGoodsTableForRule(Object, Catalogs.PriceKinds.EmptyRef());
		For Each TSRow IN Products Do
			
			AreaCode.Parameters.Code = TSRow.Code;
			SpreadsheetDocument.Put(AreaCode);
			
			If TSRow.Used Then
				AreaProduct.Parameters.Product = TSRow.Description;
			Else
				AreaProduct.Parameters.Product = "";
			EndIf;
			SpreadsheetDocument.Join(AreaProduct);
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Responsible = Users.CurrentUser();
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Object);
	
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction // GeneratePrintFormProductsCodes()

// Generate printed forms of objects
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProductCodes") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProductCodes", "Product codes", GeneratePrintFormProductsCodes(ObjectsArray, PrintObjects, PrintParameters));
		
	EndIf;
	
EndProcedure // Print()

// Fills list of catalog printing commands "Exchange rules with peripherals offline"
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Product codes
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ProductCodes";
	PrintCommand.Presentation = NStr("en='Product codes';ru='Коды товаров'");
	PrintCommand.FormsList = "ItemForm,ListForm,ChoiceForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure // AddPrintCommands()

#EndRegion

#EndIf