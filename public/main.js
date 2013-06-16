var io = new RocketIO().connect();
var repos = (new function(){
  var self = this;
  var target = $("#repos");
  this.data = {};
  this.set = function(repo){
    self.data[repo.name] = repo;
    self.display();
  };
  this.display = function(){
    target.html("");
    var sorted_repos = [];
    for(name in self.data){
      sorted_repos.push(self.data[name]);
    }
    sorted_repos = sorted_repos.sort(function(a,b){
      return a.updated_at < b.updated_at ? 1 : -1
    });
    var issue_count = 0;
    for(var i = 0; i < sorted_repos.length; i++){
      var repo = sorted_repos[i];
      var li = $("<li>");
      li.append( $("<h3>").html($("<a>").attr("href",repo.url).attr("target","_blank").text(repo.url) ));
      if(typeof repo.description === "string" && repo.description.length > 0){
        li.append( $("<p>").text(repo.description));
      }
      var issues = $("<ul>");
      for(var j = 0; j < repo.issues.length; j++){
        var issue = repo.issues[j];
        issues.append( $("<li>").append( "["+issue.number+"] " ).append(
          $("<a>").text(issue.title).attr("href", repo.url+"/issues/"+issue.number).attr("target","_blank")
        ) );
        issue_count += 1;
      }
      li.append(issues);
      target.append(li);
    }
    $("#repos_status").text(sorted_repos.length+"repos / "+issue_count+"issues");
  };
}());

io.on("connect", function(){
  $("#status .rocketio").text("connect ("+io.type+")");
  io.push("get_issues", {session_id: session_id});
});

io.on("disconnect", function(){
  $("#status .rocketio").text("disconnect");
});

io.on("issue", function(repo){
  repos.set(repo);
});

io.on("status", function(text){
  $("#status .text").text(text);
});

io.on("github_error", function(err){
  console.error(err);
});


$(function(){
  $("#btn_reload").click(function(){
    io.push("reload_issues", {session_id: session_id});
  });
});
