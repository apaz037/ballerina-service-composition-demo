import ballerina/http;
import ballerinax/docker;

@docker:Config {
    registry: ""
}

// service endpoint
endpoint http:Listener travelAgencyEP {
    port: 9090
};

// client endpoint to communicate with airline service
endpoint http:Client airlineReservationEP {
    url: "http://localhost:9091/airline"
};

// client endpoint to communicate with hotel reservation service
endpoint http:Client hotelReservationEP {
    url: "http://localhost:9092/hotel"
};

// client endpoint to communicate with car rental service
endpoint http:Client carRentalEP {
    url: "http://localhost:9093/car"
};

//  travel agency service to arrange a complete tour for our user
@http:ServiceConfig {basePath:"/travel"}
service<http:Service> travelAgencyService bind travelAgencyEP {

    // resource to arrange a tour
    @http:ResourceConfig {
        methods:["POST"],
        consumes: ["application/json"],
        produces: ["application/json"]
    }
    arrangeTour(endpoint client, http:Request inRequest) {
        http:Response outResponse;
        json inReqPayload;

        // JSON payload format for an HTTP OUT request
        json outReqPayload = {
            "Name": "",
            "ArrivalDate":"",
            "DepartureDate":"",
            "Preference":""                    
        };

        // parse the json payload from the user request
        match inRequest.getJsonPayload() {
            // validate our json payload
            json payload => inReqPayload = payload;

            // if not a valid json payload
            any => {
                outResponse.statusCode = 400;
                outResponse.setJsonPayload(
                    {"Message":"Invalid Payload - Not a valid JSON payload"});
                _ = client -> respond(outResponse);
                done;
            }
        }

        outReqPayload.Name = inReqPayload.Name;
        outReqPayload.ArrivalDate = inReqPayload.ArrivalDate;
        outReqPayload.DepartureDate = inReqPayload.DepartureDate;

        json airlinePreference = inReqPayload.Preference.Airline;
        json hotelPreference  = inReqPayload.Preference.Accommodation;
        json carPreference = inReqPayload.Preference.Car;

        //  If payload parsing fails, send a "Bad Request" message as the response
        if (outReqPayload.Name == null || outReqPayload.ArrivalDate == null || 
            outReqPayload.DepartureDate == null || airlinePreference == null ||
            hotelPreference == null || airlinePreference == null || carPreference == null) {
            
            outResponse.statusCode = 400;
            outResponse.setJsonPayload({"Message":"Bad Request - Invalid Payload"});
            _ = client -> respond(outResponse);
            done;
    }

        // reserve them an airline ticket by calling the airline reservation service
        // construct payload
        json outReqPayloadAirline = outReqPayload;
        outReqPayloadAirline.Preference = airlinePreference;

        // send a post requerst to the airline service with the appropriate pauyload and get response
        http:Response inResAirline = check airlineReservationEP -> post("/reserve", untaint outReqPayloadAirline);

        // get the reservation status
        var airlineResPayload = check inResAirline.getJsonPayload();
        string airlineStatus = airlineResPayload.Status.toString();

        // if reservation status is negative, send a failure response
        if (airlineStatus.equalsIgnoreCase("Failed")) {
            outResponse.setJsonPayload({"Message": "Failed to reserve airline! " + "Provide a valid 'Preference' for 'Airline' and try again"});
            _ = client -> respond(outResponse);
            done; 
        }
        
        // reserve a hotel room by calling the hotel reservation service
        // construct the payload
        json outReqPayloadHotel = outReqPayload;
        outReqPayloadHotel.Preference = hotelPreference;

        // Send a post request to hotel service with appropriate payload and get response
        http:Response inResHotel = check hotelReservationEP -> post("/reserve", untaint outReqPayloadHotel);

        // Get reservation status
        var hotelResPayload = check inResHotel.getJsonPayload();
        string hotelStatus = hotelResPayload.Status.toString();
        
        // if reservation status is negative, send a failure response to the user
        if (hotelStatus.equalsIgnoreCase("Failed")) {
            outResponse.setJsonPayload({"Message":"Failed to reserve hotel! " + "Provide a valid 'Preference' for 'Accommodation' and try again"});
            _ = client -> respond(outResponse);
            done;
        }
        
        // rent a car by calling the car rental service
        // construct payload
        json outReqPayloadCar = outReqPayload;
        outReqPayloadCar.Preference = carPreference;

        // send a post request to car rental service with appropriate payload and get response
        http:Response inResCar = check carRentalEP -> post("/rent", untaint outReqPayloadCar);

        // get the rental status
        var carResPayload = check inResCar.getJsonPayload();
        string carRentalStatus = carResPayload.Status.toString();

        if (carRentalStatus.equalsIgnoreCase("Failed")) {
            outResponse.setJsonPayload({"Message":"Failed to rent car! " + "Provide a valid 'Preference' for 'Car' and try again"});
            _ = client -> respond(outResponse);
            done;
        }
        
        // if all three responses are positive, send a success message to the user
        outResponse.setJsonPayload({"Message": "Congrats, you'll be on your way soon!"});
        _= client -> respond(outResponse);
    }
}
