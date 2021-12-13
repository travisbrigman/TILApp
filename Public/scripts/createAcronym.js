
// 1 - On page load, send a GET request to /api/categories. This gets all the categories in the TIL app.
$.ajax({
  url: "/api/categories/",
  type: "GET",
  contentType: "application/json; charset=utf-8"
}).then(function (response) {
  var dataToReturn = [];
  // 2 - Loop through each returned category and turn it into a JSON object and add it to dataToReturn.
  for (var i=0; i < response.length; i++) {
    var tagToTransform = response[i];
    var newTag = {
                   id: tagToTransform["name"],
                   text: tagToTransform["name"]
                 };
    dataToReturn.push(newTag);
  }
  // 3 - Get the HTML element with the ID categories and call select2() on it. This enables Select2 on the <select> in the form.
  $("#categories").select2({
    // 4 - Set the placeholder text on the Select2 input.
    placeholder: "Select Categories for the Acronym",
    // 5 - Enable tags in Select2. This allows users to dynamically create new categories that don’t exist in the input.
    tags: true,
    // 6 - Set the separator for Select2. When a user types , Select2 creates a new category from the entered text. This allows users to create categories with spaces.
    tokenSeparators: [','],
    // 7 - Set the data — the options a user can choose from — to the existing categories.
    data: dataToReturn
  });
});
