// Click a picture to toggle between fitted and actual size.
document
  .querySelectorAll(".picture")
  .forEach((picture) =>
    picture.addEventListener("click", () => picture.classList.toggle("actual")),
  )

document
  .querySelector("nav a.current")
  ?.scrollIntoView({ inline: "center", block: "nearest" })

document
  .querySelectorAll("form.theme-picker select")
  .forEach((select) => select.addEventListener("change", () => select.form.submit()))

// Offer a reload when the catalog, the theme file or a build render changes on disk.
const stamp = document.body.dataset.stamp
setInterval(async () => {
  try {
    const response = await fetch("/api/stamp", { cache: "no-store" })
    if ((await response.text()) !== stamp) {
      document.getElementById("banner").style.display = "block"
    }
  } catch (error) {
    // The server is down; keep the page and try again.
  }
}, 5000)
document.getElementById("banner").addEventListener("click", () => location.reload())
